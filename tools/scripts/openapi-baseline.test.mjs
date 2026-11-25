import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { selectBaseline } from './openapi-baseline.mjs';

const sha256 = (data) => createHash('sha256').update(data).digest('hex');

function fixture(t) {
  const cwd = mkdtempSync(join(tmpdir(), 'hasta-t47-'));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd, encoding: 'utf8' }).trim();
  git('init', '-q', '--initial-branch=base');
  git('config', 'user.name', 'T47 fixture');
  git('config', 'user.email', 'fixture@example.invalid');
  mkdirSync(join(cwd, 'docs', 'api'), { recursive: true });
  const commit = (version) => {
    writeFileSync(join(cwd, 'docs', 'api', 'openapi.json'),
      JSON.stringify({ openapi: '3.0.3', info: { title: 'Fixture', version }, paths: {} }));
    git('add', '.');
    git('commit', '-qm', version);
    return git('rev-parse', 'HEAD');
  };
  const base = commit('1.0.0');
  const bootstrapPath = join(cwd, 'bootstrap.json');
  const baseline = readFileSync(join(cwd, 'docs', 'api', 'openapi.json'));
  writeFileSync(bootstrapPath, baseline);
  return { git, commit, bootstrapPath, baseline,
    options: { cwd, base, bootstrapPath, bootstrapDigest: sha256(baseline) } };
}

test('T47: without a tag, load the pinned bootstrap instead of skipping', (t) => {
  const { options, baseline } = fixture(t);
  const selected = selectBaseline(options);
  assert.equal(selected.label, 'pinned S1 bootstrap');
  assert.deepEqual(selected.document, baseline);
});

test('T47: use the highest stable release on the trusted base, not a tag on the candidate', (t) => {
  const { git, commit, options } = fixture(t);
  git('tag', 'v1.0.0');
  commit('1.2.0');
  git('tag', 'v1.2.0');
  const base = commit('1.10.0');
  git('tag', 'v1.10.0');
  git('tag', 'v2.0.0-rc.1');
  commit('3.0.0');
  git('tag', 'v3.0.0');
  const selected = selectBaseline({ ...options, base });
  assert.equal(selected.label, 'refs/tags/v1.10.0');
  assert.equal(JSON.parse(selected.document).info.version, '1.10.0');
});

test('T47: missing or altered baselines fail closed', (t) => {
  const { git, options, bootstrapPath } = fixture(t);
  writeFileSync(bootstrapPath, '{}');
  assert.throws(() => selectBaseline(options), /digest mismatch/);
  rmSync(bootstrapPath);
  assert.throws(() => selectBaseline(options), /ENOENT/);
  assert.throws(() => selectBaseline({ ...options, base: 'deadbee' }), /trusted base/);
  git('rm', '-q', 'docs/api/openapi.json');
  git('commit', '-qm', 'no contract');
  git('tag', 'v1.1.0');
  assert.throws(() => selectBaseline({ ...options, base: git('rev-parse', 'HEAD') }),
    /missing docs\/api\/openapi\.json/);
});

test('T47: oasdiff rejects a removed operation and accepts a compatible change', (t) => {
  const oasdiff = process.env.HASTA_T47_OASDIFF;
  assert.ok(oasdiff, 'set HASTA_T47_OASDIFF to the pinned oasdiff executable');
  const cwd = mkdtempSync(join(tmpdir(), 'hasta-t47-diff-'));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  // Exercise the frozen S1 snapshot even after the real repo has release tags.
  const { options: { cwd: repo, base } } = fixture(t);
  const { document } = selectBaseline({ cwd: repo, base });
  const baseline = join(cwd, 'baseline.json');
  const candidate = join(cwd, 'candidate.json');
  writeFileSync(baseline, document);
  const compare = (doc) => {
    writeFileSync(candidate, JSON.stringify(doc));
    const result = spawnSync(oasdiff, ['breaking', baseline, candidate, '--fail-on', 'ERR'],
      { cwd, encoding: 'utf8' });
    assert.ifError(result.error);
    return result;
  };
  const breaking = JSON.parse(document);
  assert.ok(breaking.paths['/auth/refresh'], 'bootstrap must protect actual S1 routes');
  delete breaking.paths['/auth/refresh'];
  const red = compare(breaking);
  assert.equal(red.status, 1, red.stderr);
  assert.match(red.stdout, /api-path-removed/);
  const compatible = JSON.parse(document);
  compatible.info.description += ' Documentation-only update.';
  const green = compare(compatible);
  assert.equal(green.status, 0, green.stdout + green.stderr);
});
