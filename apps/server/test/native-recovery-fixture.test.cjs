const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');
const { test } = require('node:test');
const { uuid7 } = require('../dist/modules/auth/credentials');
const { startRecoveryFixture } = require('./native-recovery-api.cjs');

test('T30 fixture plumbing (not native): local browser page, signed exchange and DB postcondition', async () => {
  const app = await startRecoveryFixture(0);
  try {
    const origin = await app.getUrl();
    const get = (path) => fetch(`${origin}/${path}`);
    const post = (path, data) => fetch(`${origin}/${path}`, { method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Idempotency-Key': uuid7() }, body: JSON.stringify(data) });
    const enroll = async () => {
      const device_proof = randomBytes(32).toString('hex');
      const response = await post('v1/auth/device/register', { raw_device_id: uuid7(),
        device_proof, platform: 'android', os_version: '34', app_version: '1.0.0' });
      assert.equal(response.status, 200);
      return { device_proof, device_token: (await response.json()).device_token };
    };
    assert.equal((await get('_native/recovery/ready')).status, 204);
    const old = await enroll(), next = await enroll();
    assert.equal((await post('v1/auth/guest', { ...old, locale: 'en' })).status, 200);
    assert.equal((await post('_native/recovery/seed', {})).status, 204);
    assert.equal((await get('_native/recovery/verify')).status, 409);
    const started = await post('v1/auth/recover:start', { ...next, provider: 'google' });
    assert.equal(started.status, 200);
    const url = new URL((await started.json()).auth_url);
    const query = new URLSearchParams(['state', 'nonce', 'code_challenge'].map((key) => [key, url.searchParams.get(key)]));
    assert.equal((await get('_native/recovery/consent?state=invalid')).status, 400);
    const page = await get(`_native/recovery/consent?${query}`);
    assert.equal(page.status, 200);
    assert.equal(page.headers.get('cache-control'), 'no-store');
    const match = /intent:\/\/callback\/complete\?state=([\w-]+)&amp;code=([\w-]+)#Intent;scheme=hasta-recovery-qa;package=app\.hasta\.mobile;end/.exec(await page.text());
    assert.ok(match, 'fixture provides an Android browser return link');
    const completed = await post('v1/auth/recover:complete', { ...next, state: match[1], code: match[2] });
    assert.equal(completed.status, 200);
    assert.equal((await get('_native/recovery/verify')).status, 204);
  } finally { await app.close(); }
});
