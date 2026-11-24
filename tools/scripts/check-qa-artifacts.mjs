import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';

const [debug, release, platform = 'android'] = process.argv.slice(2);
assert.ok(debug && release && ['android', 'ios'].includes(platform), 'Pass debug and release artifact directories and optional ios platform');
const marker = 'HASTA_QA_FIXTURE_PANEL_V1';
const fixtures = ['tester.a', 'tester.b', 'tester.social', 'tester.premium', 'tester.minor', 'tester.fresh'];
const contents = (dir) => readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
  const path = join(dir, entry.name);
  return entry.isDirectory() ? contents(path) : [path];
});
const kernel = contents(debug).find((path) => basename(path) === 'kernel_blob.bin');
assert.ok(kernel, 'Debug artifact must contain the Dart kernel');
const debugPayload = readFileSync(kernel);
for (const value of [marker, ...fixtures, 'qa/guest']) {
  assert.ok(debugPayload.includes(value), `Missing debug positive control: ${value}`);
}
const releaseFiles = contents(release);
assert.ok(releaseFiles.some((path) => platform === 'android'
  ? basename(path) === 'libapp.so'
  : basename(path) === 'App' && basename(dirname(path)) === 'App.framework'
), 'Release artifact must contain the Dart AOT payload');
assert.ok(!releaseFiles.some((path) => basename(path) === 'kernel_blob.bin'), 'Release must not contain a debug kernel');
for (const path of releaseFiles) {
  const payload = readFileSync(path);
  for (const value of [marker, 'Hasta QA fixtures', 'Reset fixture before opening', ...fixtures, 'qa/guest']) {
    assert.ok(!payload.includes(value) && !payload.includes(Buffer.from(value, 'utf16le')), `QA payload in ${path}: ${value}`);
  }
}
console.log(`T36: PASS (${platform}: QA-positive debug artifact; QA excluded from release with the same defines)`);
