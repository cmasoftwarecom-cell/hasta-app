import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

const repo = new URL('../../', import.meta.url);
const source = 'assets/design-tokens.json';
const nested = 'assets/assets/design-tokens.json';
const generated = 'apps/mobile/lib/design_tokens.g.dart';
const script = 'tools/scripts/design-tokens.mjs';

function fixture(t, edit) {
  const dir = mkdtempSync(join(tmpdir(), 'hasta-tokens-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  for (const path of ['tools/scripts', 'assets/assets', 'apps/mobile/lib']) {
    mkdirSync(join(dir, path), { recursive: true });
  }
  for (const path of [script, nested]) copyFileSync(new URL(path, repo), join(dir, path));
  if (edit) {
    const input = JSON.parse(readFileSync(new URL(source, repo), 'utf8'));
    edit(input);
    writeFileSync(join(dir, source), JSON.stringify(input));
  }
  return { dir, run: (...args) => spawnSync(process.execPath, [join(dir, script), ...args], {
    encoding: 'utf8',
  }) };
}

test('DS: nested legacy source alone is rejected with the canonical path', (t) => {
  const result = fixture(t).run();
  assert.equal(result.status, 1);
  assert.match(result.stderr, /git mv assets\/assets\/design-tokens\.json assets\/design-tokens\.json/);
});

test('DS: resolves chained aliases and rejects generated drift', (t) => {
  const { dir, run } = fixture(t, (input) => {
    input.component.button.primary.background.$value = '{color.line.focus}';
    input.color.bg.brand.$value = '#123456';
  });
  const result = run();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /assets\/design-tokens\.json/);
  const path = join(dir, generated);
  const dart = readFileSync(path, 'utf8');
  assert.match(dart, /bgBrand = Color\(0xFF123456\)/);
  for (const name of ['primaryButton = bgBrand', 'primaryButtonPressed = bgBrandPressed',
    'primaryButtonDisabled = bgBrandDisabled', 'lineHeightBody = 1.65', 'Noto Sans Myanmar']) {
    assert.ok(dart.includes(name), name);
  }
  assert.equal(run('--check').status, 0);
  writeFileSync(path, dart.replace('0xFF123456', '0xFF654321'));
  const drift = run('--check');
  assert.equal(drift.status, 1);
  assert.match(drift.stderr, /Regenerate apps\/mobile\/lib\/design_tokens\.g\.dart/);
});

const button = (input) => input.component.button.primary;
for (const [name, edit, message] of [
  ['unknown alias', (i) => { button(i).background.$value = '{color.bg.nope}'; }, /color\.bg\.nope.*background/],
  ['cycle', (i) => { i.color.bg.brand.$value = '{color.line.focus}'; }, /Circular.*color\.bg\.brand/],
  ['missing disabled fill', (i) => { delete i.color.bg.brandDisabled; }, /required token missing: color\.bg\.brandDisabled/],
  ['low line height', (i) => { i.typography.lineHeight.body.$value = 1.2; }, /lineHeight\.body.*1\.65/],
  ['missing Myanmar fonts', (i) => { i.typography.fontFamily.base.$value = ['Inter']; }, /fontFamily\.base.*Myanmar/],
  ['wrong pressed fill', (i) => { button(i).backgroundPressed.$value = '{color.bg.brand}'; }, /backgroundPressed.*brandPressed/],
]) {
  test(`DS: rejects ${name}`, (t) => {
    const result = fixture(t, edit).run();
    assert.equal(result.status, 1);
    assert.match(result.stderr, message);
  });
}

test('DS: CI gates check committed Dart before T47', () => {
  const ci = readFileSync(new URL('.github/workflows/ci.yml', repo), 'utf8');
  const gates = ci.match(/^  gates:\n([\s\S]*?)(?=^  [\w-]+:\n|(?![\s\S]))/m)?.[1] ?? '';
  assert.match(gates, /node tools\/scripts\/design-tokens\.mjs --check[\s\S]+ - name: T47/);
});
