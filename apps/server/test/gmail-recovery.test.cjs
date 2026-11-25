const assert = require('node:assert/strict');
const { createHash, randomBytes } = require('node:crypto');
const { test } = require('node:test');
const { createApp, Database } = require('../dist/main');
const { sha, uuid7 } = require('../dist/modules/auth/credentials');
const { GoogleOAuth } = require('../dist/modules/identity/google-oauth');
const { LocalGoogleClient, signedProof, fakeEmail } = require('./google-proof-fixture.cjs');

test('T30/T37/T39: lost-device recovery restores only an existing linked account on a proved installation', async () => {
  const database = new URL(process.env.HASTA_DATABASE_URL);
  assert.equal(database.pathname, '/hasta_test');
  assert.ok(['127.0.0.1', 'localhost', '[::1]'].includes(database.hostname));
  Object.assign(process.env, { HASTA_ENV: 'test', HASTA_AUTH_GOOGLE_LINK_ENABLED: 'false',
    HASTA_AUTH_SECRET: randomBytes(32).toString('hex'), HASTA_DEVICE_PEPPER: randomBytes(32).toString('hex'),
    HASTA_ACCESS_TOKEN_TTL_SECONDS: '900', HASTA_REFRESH_TOKEN_TTL_SECONDS: '2592000',
    HASTA_DEVICE_TOKEN_TTL_SECONDS: '31536000', HASTA_DEVICE_REGISTER_PER_HOUR: '10',
    HASTA_GUEST_CREATE_PER_HOUR: '3' });
  const cfg = { clientId: 'local-recovery', clientSecret: randomBytes(32).toString('hex'),
    redirectUri: 'https://callback.example.invalid/recover' };
  const subject = `synthetic-${uuid7()}`;
  const codes = new Map();
  let exchanged = 0;
  class Transport extends LocalGoogleClient {
    async getToken({ code, codeVerifier, redirect_uri }) {
      exchanged++;
      const fixture = codes.get(code);
      assert.ok(fixture);
      codes.delete(code);
      assert.equal(redirect_uri, cfg.redirectUri);
      assert.equal(createHash('sha256').update(codeVerifier).digest('base64url'), fixture.challenge);
      if (fixture.wait) {
        fixture.entered();
        await fixture.wait;
      }
      return { tokens: { id_token: fixture.token } };
    }
  }
  const google = new GoogleOAuth(cfg, new Transport(cfg));
  const app = await createApp(() => () => google);
  const db = app.get(Database);
  try {
    await app.listen(0, '127.0.0.1');
    const url = await app.getUrl();
    const call = async (path, data, token, key = uuid7(), method = 'POST') => {
      const res = await fetch(`${url}/v1/${path}`, { method, headers: {
        'content-type': 'application/json', 'idempotency-key': key, ...(token ? { authorization: `Bearer ${token}` } : {}),
      }, body: data && JSON.stringify(data) });
      return { status: res.status, replay: res.headers.get('idempotent-replayed'), data: await res.json() };
    };
    const enroll = async () => {
      const device_proof = randomBytes(32).toString('hex');
      const result = await call('auth/device/register', { raw_device_id: uuid7(), device_proof,
        platform: 'ios', app_version: '1.0.0', os_version: '17.0' });
      assert.equal(result.status, 200);
      return { credentials: { device_token: result.data.device_token, device_proof }, hash: result.data.device_hash };
    };
    const guest = (device, key) => call('auth/guest', { ...device.credentials, locale: 'en' }, undefined, key);
    const me = (token) => call('me', undefined, token, undefined, 'GET');
    const start = (device, key) => call('auth/recover:start', { ...device.credentials, provider: 'google' }, undefined, key);
    const complete = (device, input, key) => call('auth/recover:complete', { ...device.credentials, ...input }, undefined, key);
    const oauth = (response, claims = {}, options = {}) => {
      assert.equal(response.status, 200, JSON.stringify(response.data));
      assert.equal(response.data.expires_in, 300);
      const { state, nonce, auth_url } = response.data;
      const params = new URL(auth_url).searchParams;
      assert.equal(params.get('state'), state);
      assert.equal(params.get('nonce'), nonce);
      assert.equal(params.get('code_challenge_method'), 'S256');
      const code = uuid7();
      codes.set(code, { challenge: params.get('code_challenge'), ...options,
        token: signedProof({ iss: 'https://accounts.google.com', aud: cfg.clientId, nonce, sub: subject,
          email: fakeEmail, exp: Math.floor(Date.now() / 1000) + 60, email_verified: true, ...claims }, options.signed) });
      return { state, code };
    };
    const old = await enroll(), fresh = await enroll(), other = await enroll(), occupied = await enroll();
    const oldKey = uuid7();
    const previous = (await guest(old, oldKey)).data;
    const second = (await guest(old)).data;
    const unrelated = (await guest(occupied)).data;
    const id = previous.account.id, bearer = previous.access_token;
    const startLink = await call('auth/identities/google/link:start', old.credentials, bearer);
    const link = oauth(startLink);
    assert.equal((await call('auth/identities/google/link:complete', { ...old.credentials, ...link }, bearer)).status, 200);
    const before = await db.accounts.count();
    const startKey = uuid7(), consent = await start(fresh, startKey);
    assert.deepEqual(await start(fresh, startKey), { ...consent, replay: 'true' });
    assert.equal((await start(fresh)).data.error.code, 'request_in_progress');
    assert.equal((await start({ credentials: { ...fresh.credentials, device_proof: other.credentials.device_proof } })).status, 401);
    assert.equal((await call('auth/recoverxstart', { ...fresh.credentials, provider: 'google' })).status, 404);
    assert.equal((await call('auth/recover:start', { ...fresh.credentials, provider: 'apple' })).status, 400);

    const absent = oauth(consent, { sub: `unlinked-${uuid7()}` }); // Same email must not count as a match.
    assert.equal((await complete(other, absent)).data.error.code, 'token_expired');
    assert.equal((await complete(fresh, { ...absent, id_token: 'not-accepted' })).status, 400);
    const absentKey = uuid7();
    assert.equal((await complete(fresh, absent, absentKey)).status, 404);
    assert.equal((await complete(fresh, absent, absentKey)).status, 404);
    assert.equal((await complete(fresh, absent)).data.error.code, 'token_expired');
    assert.equal(await db.accounts.count(), before);
    assert.equal((await me(bearer)).status, 200);
    assert.equal((await complete(occupied, oauth(await start(occupied)))).data.error.code, 'guest_exists_on_target');
    assert.equal((await me(unrelated.access_token)).status, 200);
    assert.equal((await complete(fresh, oauth(await start(fresh), {}, { signed: false }))).status, 401);
    assert.equal((await complete(fresh, oauth(await start(fresh), { email_verified: false }))).status, 422);
    const pausedProof = oauth(await start(fresh));
    await db.accounts.update({ where: { id }, data: { status: 'paused' } });
    assert.equal((await complete(fresh, pausedProof)).status, 404);
    await db.accounts.update({ where: { id }, data: { status: 'active' } });
    const expired = oauth(await start(fresh));
    await db.auth_requests.updateMany({ where: { scope: `recover-google-state:${fresh.hash}`, fingerprint: sha(expired.state) },
      data: { expires_at: new Date(Date.now() - 1000) } });
    assert.equal((await complete(fresh, expired)).data.error.code, 'token_expired');
    assert.equal(exchanged, 6);

    let entered, release;
    const waiting = new Promise((resolve) => { release = resolve; });
    const reached = new Promise((resolve) => { entered = resolve; });
    const good = oauth(await start(fresh), {}, { wait: waiting, entered });
    const recoveryKey = uuid7();
    const pending = complete(fresh, good, recoveryKey);
    let recovered;
    try {
      // A broken route fails this assertion instead of hanging the suite.
      assert.equal(await Promise.race([reached.then(() => 'provider'), pending.then(() => 'completed')]), 'provider');
      assert.equal((await complete(fresh, good, recoveryKey)).data.error.code, 'request_in_progress');
      assert.equal((await complete(fresh, good)).data.error.code, 'token_expired');
      assert.equal((await me(bearer)).status, 200);
    } finally {
      release();
      recovered = await pending;
    }
    assert.equal(recovered.status, 200, JSON.stringify(recovered.data));
    assert.equal(recovered.data.account.id, id);
    assert.equal(recovered.data.is_new_account, false);
    assert.equal(recovered.data.revoked_other_sessions, 2);
    assert.equal(recovered.data.device_binding.device_hash, fresh.hash);
    assert.equal(recovered.data.device_binding.role, 'primary');
    assert.equal(await db.accounts.count(), before);
    assert.equal(await db.identities.count({ where: { account_id: id, provider: 'google' } }), 1);
    assert.equal(await db.device_bindings.count({ where: { account_id: id, revoked_at: null, device_hash: fresh.hash } }), 1);
    assert.equal(await db.device_bindings.count({ where: { account_id: id, revoked_at: null, device_hash: old.hash } }), 0);
    assert.equal(await db.sessions.count({ where: { account_id: id, revoked_reason: 'device_recovery', device_hash: old.hash } }), 2);
    assert.equal((await me(bearer)).status, 401);
    assert.equal((await me(second.access_token)).status, 401);
    assert.equal((await call('auth/refresh', { ...old.credentials, refresh_token: previous.refresh_token })).status, 401);
    assert.equal((await guest(old, oldKey)).status, 401);
    assert.equal((await me(unrelated.access_token)).status, 200);
    assert.deepEqual(await complete(fresh, good, recoveryKey), { ...recovered, replay: 'true' });
    assert.equal((await complete(fresh, { ...good, code: uuid7() }, recoveryKey)).data.error.code, 'idempotency_conflict');
    assert.equal((await complete(other, good, recoveryKey)).data.error.code, 'token_expired');
    assert.equal((await me(recovered.data.access_token)).data.account.id, id);
    assert.equal(exchanged, 7);

    // A second valid recovery moves the binding again; a cached first reply must not return dead credentials.
    const moved = await complete(other, oauth(await start(other)));
    assert.equal(moved.status, 200);
    assert.equal(moved.data.account.id, id);
    assert.equal(moved.data.revoked_other_sessions, 1);
    assert.equal((await complete(fresh, good, recoveryKey)).status, 401);
    assert.equal((await me(moved.data.access_token)).status, 200);
    const oldLogin = await guest(old);
    assert.equal(oldLogin.status, 200);
    assert.notEqual(oldLogin.data.account.id, id);
    assert.equal(oldLogin.data.account.is_guest, true);

    const disabled = await createApp();
    try {
      await disabled.listen(0, '127.0.0.1');
      const response = await fetch(`${await disabled.getUrl()}/v1/auth/recover:start`, {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'Idempotency-Key': uuid7() },
        body: JSON.stringify({ ...other.credentials, provider: 'google' }),
      });
      assert.equal(response.status, 404);
      assert.equal((await response.json()).error.code, 'not_found');
    } finally { await disabled.close(); }
  } finally { await app.close(); }
});
