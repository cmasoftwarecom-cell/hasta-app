const assert = require('node:assert/strict');
const { cpSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join, resolve } = require('node:path');
const { test } = require('node:test');

const sha = '0123456789abcdef'.repeat(2) + '01234567';
for (const [name, env, baked, status, expected] of [
  ['staging exposes only the baked full SHA', 'staging', sha, 200, { status: 'ok', env: 'staging', commit: sha }],
  ['staging without a baked SHA fails closed', 'staging', undefined, 503],
  ['staging with a malformed baked SHA fails closed', 'staging', 'not-a-full-sha', 503],
  ['production remains a minimal probe', 'production', sha, 200, { status: 'ok' }],
  ['test remains a minimal probe', 'test', undefined, 200, { status: 'ok' }],
]) {
  test(`staging health contract: ${name}`, async (t) => {
    const root = mkdtempSync(join(tmpdir(), 'hasta-health-'));
    t.after(() => rmSync(root, { recursive: true, force: true }));
    cpSync(resolve(__dirname, '../dist'), join(root, 'dist'), { recursive: true });
    symlinkSync(resolve(__dirname, '../node_modules'), join(root, 'node_modules'), 'dir');
    const buildCommit = join(root, 'dist/build-commit');
    rmSync(buildCommit, { force: true });
    if (baked !== undefined) writeFileSync(buildCommit, baked);
    const prior = { HASTA_ENV: process.env.HASTA_ENV, GIT_COMMIT: process.env.GIT_COMMIT };
    Object.assign(process.env, { HASTA_ENV: env, GIT_COMMIT: 'f'.repeat(40) });
    t.after(() => {
      for (const [key, value] of Object.entries(prior)) {
        if (value === undefined) delete process.env[key];
        else process.env[key] = value;
      }
    });
    const { createApp, Database } = require(join(root, 'dist/main.js'));
    const app = await createApp(() => ({}));
    try {
      // The probe tests the real Nest route without touching a database.
      t.mock.method(app.get(Database), '$executeRaw', async () => 0);
      await app.listen(0, '127.0.0.1');
      const result = await fetch(`${await app.getUrl()}/health`);
      assert.equal(result.status, status);
      assert.equal(result.headers.get('cache-control'), 'no-store');
      const body = await result.json();
      if (expected) assert.deepEqual(body, expected);
      else {
        assert.equal(body.error.status, 503);
        assert.equal(body.error.code, 'internal_error');
        assert.deepEqual(body.error.details, {});
      }
    } finally {
      await app.close();
    }
  });
}
