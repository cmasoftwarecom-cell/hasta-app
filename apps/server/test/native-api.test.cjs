const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');
const { test } = require('node:test');
const { nativeAuthEnv, startNativeApi } = require('./native-api.cjs');
const { uuid7 } = require('../dist/modules/auth/credentials');

test('T40/T41 native API: reject an empty policy handoff before listening', () => {
  assert.throws(() => nativeAuthEnv(''), {
    message: 'invalid or missing HASTA_DEVICE_REGISTER_PER_HOUR',
  });
});

test('T40/T41 native API: fresh iOS enrollment and repeat guest entry over HTTP', async () => {
  // The launcher must populate auth settings itself, not rely on inherited keys.
  for (const name of Object.keys(process.env)) {
    if (/^HASTA_(?:.*_TTL_SECONDS|.*_PER_HOUR|AUTH_SECRET|DEVICE_PEPPER)$/.test(name)) {
      delete process.env[name];
    }
  }
  const app = await startNativeApi(0);
  try {
    const url = await app.getUrl();
    const post = async (path, body) => {
      const response = await fetch(`${url}/v1/${path}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'idempotency-key': uuid7() },
        body: JSON.stringify(body),
      });
      assert.equal(response.status, 200, path);
      return response.json();
    };
    const device_proof = randomBytes(32).toString('hex');
    const { device_token } = await post('auth/device/register', {
      raw_device_id: uuid7(), device_proof, platform: 'ios',
      app_version: '1.0.0', os_version: '18.0',
    });
    const guest = () => post('auth/guest', { device_token, device_proof, locale: 'my' });
    const first = await guest();
    const again = await guest();
    assert.equal(first.account.is_guest, true);
    assert.equal(first.is_new_account, true);
    assert.equal(Boolean(first.access_token && first.refresh_token), true);
    assert.equal(again.is_new_account, false);
    assert.equal(again.account.id === first.account.id, true);
  } finally {
    await app.close();
  }
});
