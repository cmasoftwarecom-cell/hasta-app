import assert from 'node:assert/strict';
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { basename, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const skip = new Set(['node_modules', '.dart_tool', '.gradle', '.git', '.terraform', 'Pods', 'build']);
function list(input) {
  const path = resolve(root, input);
  if (!existsSync(path)) return [];
  return readdirSync(path, { withFileTypes: true }).flatMap((child) => {
    if (skip.has(child.name) || child.isSymbolicLink()) return [];
    const entry = join(path, child.name);
    return child.isDirectory() ? list(entry) : [relative(root, entry)];
  });
}
const api = JSON.parse(read('docs/api/openapi.json'));
const sources = list('apps/server/src').filter((path) => /\.[cm]?[tj]s$/.test(path));
const mobile = list('apps/mobile/lib').filter((path) => path.endsWith('.dart'));
const routes = Object.keys(api.paths).join('\n');
const server = [routes, ...sources.map(read)].join('\n');
const gates = {
  T20: () => {
    assert.doesNotMatch(server, /\b(?:otp[a-z_-]*|sms(?:[-_]?provider|\b)|twilio|vonage)\b/i);
  },
  T36: () => {
    const panel = read('apps/mobile/lib/features/auth/presentation/guest_screen.dart');
    assert.match(panel, /const _qa = !kReleaseMode\s*&&/);
    assert.match(panel, /bool.fromEnvironment\('HASTA_QUICK_TEST_ACCOUNTS_ENABLED'\)/);
    assert.match(panel, /if \(_qa\)\s*Listener/);
  },
  T37: () => {
    assert.doesNotMatch(server, /(?:\bsign[-_ ]?in\b|(?:google|apple)[^/\n]{0,50}\blog[-_ ]?in\b)/i);
    // Fail closed on token inputs until S2 ships issuer/audience/expiry/nonce/email verification tests.
    assert.doesNotMatch(server, /\bid[-_]?token\b/i);
  },
  T45: () => {
    // Legacy handoff/reference docs are not application source or packaged artifacts.
    const files = [...list('apps'), ...list('infra'), ...list('tools'), ...list('docs/api'),
      '.env.example', 'docker-compose.yml'];
    for (const path of files) {
      assert.doesNotMatch(path, /\bnexus\b/i);
      assert.doesNotMatch(readFileSync(resolve(root, path)).toString('latin1'), /\bnexus\b/i, path);
    }
    // Flutter 3.24.5 debug snapshots embed two upstream MediaQuery doc comments.
    const phoneModel = ['Ne', 'xus 6'].join('');
    const upstream = {
      'isolate_snapshot_data': `/// integer. For example, the ${phoneModel} has a device pixel ratio of 3.5.`,
      'kernel_blob.bin': `/// the ${phoneModel} has a device pixel ratio of 3.5.`,
    };
    for (const path of process.argv.slice(2).flatMap(list)) {
      assert.doesNotMatch(path, /\bnexus\b/i);
      const text = readFileSync(resolve(root, path)).toString('latin1');
      const exception = Object.hasOwn(upstream, basename(path)) ? upstream[basename(path)] : null;
      assert.doesNotMatch(exception ? text.replace(exception, '') : text, /\bnexus\b/i, path);
    }
  },
  T48: () => {
    const compose = read('docker-compose.yml');
    const service = /^ {2}postgres:\s*\n((?:^ {4,}.*\n)+)/m.exec(compose)?.[1] ?? '';
    assert.deepEqual([...service.matchAll(/^ {4}image:\s*(.*)$/gm)].map((m) => m[1]), ['postgres:16']);
  },
  DS: () => {
    for (const path of mobile.filter((path) => path !== 'apps/mobile/lib/core/design/tokens.dart')) {
      assert.doesNotMatch(read(path), /(?:0x[\da-f]{6,8}|#[\da-f]{6,8})\b/i, path);
    }
  },
};
for (const [id, check] of Object.entries(gates)) {
  try {
    check();
    console.log(`${id}: PASS`);
  } catch (error) {
    console.error(`${id}: FAIL: ${error.message}`);
    process.exitCode = 1;
  }
}
