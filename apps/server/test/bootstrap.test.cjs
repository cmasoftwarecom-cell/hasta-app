const assert = require('node:assert/strict');
const { test } = require('node:test');
const { createApp, Database } = require('../dist/main');

test('S0-SMOKE: Nest HTTP starts; migrated PostgreSQL serves Prisma queries', async () => {
  const database = new URL(process.env.HASTA_DATABASE_URL);
  assert.equal(database.pathname, '/hasta_test', 'use the isolated database');
  const app = await createApp();
  try {
    const prisma = app.get(Database);
    await app.listen(0, '127.0.0.1');
    const res = await fetch(`${await app.getUrl()}/health`);
    assert.equal(res.status, 200);
    assert.ok(res.headers.get('x-request-id'));
    assert.deepEqual(await res.json(), { status: 'ok' });
    const [info] = await prisma.$queryRaw`SELECT current_setting('server_version_num')::int AS version`;
    assert.equal(Math.trunc(info.version / 10000), 16);
    const models = await prisma.$queryRaw`SELECT tablename FROM pg_tables WHERE schemaname = 'public'`;
    for (const name of ['accounts', 'identities', 'device_bindings', 'sessions',
      'transfer_tokens', 'device_cooldowns', 'abuse_logs', 'profiles']) {
      assert.ok(models.some(({ tablename }) => tablename === name), `${name} is migrated`);
    }
    assert.equal(await prisma.accounts.count(), 0);
  } finally {
    await app.close();
  }
});
