const { randomBytes } = require('node:crypto');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { parseEnv } = require('node:util');

const policyNames = [
  'HASTA_DEVICE_REGISTER_PER_HOUR',
  'HASTA_GUEST_CREATE_PER_HOUR',
  'HASTA_DEVICE_TOKEN_TTL_SECONDS',
  'HASTA_ACCESS_TOKEN_TTL_SECONDS',
  'HASTA_REFRESH_TOKEN_TTL_SECONDS',
];

class NativeConfigError extends Error {}

function nativeAuthEnv(example) {
  const defaults = parseEnv(example);
  const env = {};
  for (const name of policyNames) {
    const value = Number(defaults[name]);
    if (!Number.isSafeInteger(value) || value < 1 || value > 31_536_000) {
      throw new NativeConfigError(`invalid or missing ${name}`);
    }
    env[name] = String(value);
  }
  env.HASTA_DEVICE_PEPPER = randomBytes(32).toString('hex');
  env.HASTA_AUTH_SECRET = randomBytes(32).toString('hex');
  env.HASTA_QUICK_TEST_ACCOUNTS_ENABLED = 'false';
  return env;
}

async function startNativeApi(port = 3000, fixture) {
  const url = URL.canParse(process.env.HASTA_DATABASE_URL ?? '')
    ? new URL(process.env.HASTA_DATABASE_URL)
    : null;
  if (process.env.HASTA_ENV !== 'test' || !url || url.protocol !== 'postgresql:' ||
      url.hostname !== '127.0.0.1' || url.pathname !== '/hasta_test' ||
      url.search || url.hash) {
    throw new NativeConfigError('requires test mode and loopback hasta_test PostgreSQL');
  }
  // Load only the test policy settings. Never import example credential placeholders
  // or rely on process substitution exporting settings in the runner's shell.
  Object.assign(process.env, nativeAuthEnv(readFileSync(resolve(__dirname, '../../../.env.example'), 'utf8')));
  const { createApp } = require('../dist/main');
  const app = await createApp(fixture?.providerFactory, { localQrQa: fixture?.localQrQa === true });
  try {
    fixture?.configure(app);
    await app.listen(port, '127.0.0.1');
    return app;
  } catch (error) {
    await app.close();
    throw error;
  }
}

if (require.main === module) {
  startNativeApi().catch((error) => {
    const reason = error instanceof NativeConfigError ? error.message : 'startup failed';
    console.error(`Native test API: ${reason}`);
    process.exitCode = 1;
  });
}

module.exports = { nativeAuthEnv, startNativeApi };
