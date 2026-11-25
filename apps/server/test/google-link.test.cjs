const assert = require('node:assert/strict');
const { createHash, randomBytes } = require('node:crypto');
const { test } = require('node:test');
const { createApp, Database } = require('../dist/main');
const { uuid7, sha } = require('../dist/modules/auth/credentials');
const { GoogleOAuth } = require('../dist/modules/identity/google-oauth');
const { LocalGoogleClient, signedProof, fakeEmail } = require('./google-proof-fixture.cjs');

const clientId = 'local-client';
const redirectUri = 'https://callback.example.invalid/link';
const prefix = 'auth/identities/google';
const authorize = `${prefix}/link:start`;
const finish = `${prefix}/link:complete`;

test('S2 sessions and T37/T38/T39: device proof, state, code verification, no merge and scoped revocation', async () => {
  const database = new URL(process.env.HASTA_DATABASE_URL);
  assert.equal(database.pathname, '/hasta_test');
  assert.ok(['127.0.0.1', 'localhost', '[::1]'].includes(database.hostname));
  Object.assign(process.env, { HASTA_ENV: 'test', HASTA_AUTH_GOOGLE_LINK_ENABLED: 'false',
    HASTA_AUTH_SECRET: randomBytes(32).toString('hex'), HASTA_DEVICE_PEPPER: randomBytes(32).toString('hex'),
    HASTA_ACCESS_TOKEN_TTL_SECONDS: '900', HASTA_REFRESH_TOKEN_TTL_SECONDS: '2592000',
    HASTA_DEVICE_TOKEN_TTL_SECONDS: '31536000', HASTA_DEVICE_REGISTER_PER_HOUR: '10',
    HASTA_GUEST_CREATE_PER_HOUR: '3' });
  const codes = new Map();
  const subject = `synthetic-${uuid7()}`;
  let exchanges = 0;
  class TestTransport extends LocalGoogleClient {
    async getToken({ code, codeVerifier, redirect_uri }) {
      exchanges++;
      const expected = codes.get(code);
      codes.delete(code);
      assert.ok(expected);
      assert.equal(redirect_uri, redirectUri);
      assert.equal(createHash('sha256').update(codeVerifier).digest('base64url'), expected.challenge);
      await expected.wait;
      return { tokens: { id_token: expected.token } };
    }
  }
  const localConfig = { clientId, clientSecret: randomBytes(32).toString('base64url'), redirectUri };
  const adapter = new GoogleOAuth(localConfig, new TestTransport(localConfig));
  const app = await createApp(() => () => adapter);
  const db = app.get(Database);
  try {
    await app.listen(0, '127.0.0.1');
    const url = await app.getUrl();
    const call = async (path, { data, token, key = uuid7(), method = 'POST', headers = {} } = {}) => {
      const res = await fetch(`${url}/v1/${path}`, {
        method, headers: { 'content-type': 'application/json', 'idempotency-key': key,
          ...(token ? { authorization: `Bearer ${token}` } : {}), ...headers },
        body: data && JSON.stringify(data),
      });
      return { status: res.status, replay: res.headers.get('idempotent-replayed'),
        data: res.status === 204 ? null : await res.json() };
    };
    const enroll = async (targetAccount) => {
      const device_proof = randomBytes(32).toString('hex');
      const reg = await call('auth/device/register', { data: { raw_device_id: uuid7(),
        device_proof, platform: 'android', app_version: '1.0.0', os_version: '14' } });
      assert.equal(reg.status, 200);
      const credentials = { device_proof, device_token: reg.data.device_token };
      if (targetAccount) await db.device_bindings.create({ data: { id: uuid7(), account_id: targetAccount,
        device_hash: reg.data.device_hash, platform: 'android', role: 'secondary' } });
      const guest = await call('auth/guest', { data: { ...credentials, locale: 'my' } });
      assert.equal(guest.status, 200);
      return { credentials, token: guest.data.access_token, id: guest.data.account.id, hash: reg.data.device_hash,
        refresh: guest.data.refresh_token };
    };
    const a = await enroll(), b = await enroll();
    const beforeAccounts = await db.accounts.count();
    const start = (person, key) => call(authorize, { data: person.credentials, token: person.token, key });
    const consent = async (person, options = {}) => {
      const started = await start(person, options.key);
      assert.equal(started.status, 200, JSON.stringify(started.data));
      const { state, nonce, auth_url, expires_in } = started.data;
      assert.equal(expires_in, 300);
      const browser = new URL(auth_url);
      assert.equal(browser.origin, 'https://accounts.google.com');
      assert.equal(browser.searchParams.get('state'), state);
      assert.equal(browser.searchParams.get('nonce'), nonce);
      assert.equal(browser.searchParams.get('access_type'), 'online');
      assert.equal(browser.searchParams.get('code_challenge_method'), 'S256');
      const code = uuid7();
      codes.set(code, { challenge: browser.searchParams.get('code_challenge'), wait: options.wait,
        token: signedProof({ iss: 'https://accounts.google.com', aud: clientId,
          exp: Math.floor(Date.now() / 1000) + 60, nonce, sub: subject, email_verified: true, ...options.claims }, options.signed) });
      return { started, state, code };
    };
    const complete = (person, { state, code }, key, extra = {}) =>
      call(finish, { data: { ...person.credentials, state, code, ...extra }, token: person.token, key });
    const list = (person) => call('auth/sessions', { method: 'GET', token: person.token });
    const revoke = (person, path, key) => call(`auth/sessions${path}`, { method: 'DELETE', token: person.token, key,
      headers: { 'device-token': person.credentials.device_token, 'device-proof': person.credentials.device_proof } });
    assert.equal((await revoke(a, '?others=true')).data.error.code, 'recovery_required');
    assert.equal((await call(authorize, { data: a.credentials })).status, 401);
    assert.equal((await call(`${prefix}/linkxstart`, { data: a.credentials, token: a.token })).status, 404);
    assert.equal((await call(authorize, { data: b.credentials, token: a.token })).status, 401);
    const keyStart = uuid7(), good = await consent(a, { key: keyStart });
    assert.deepEqual((await start(a, keyStart)), { ...good.started, replay: 'true' });
    assert.equal((await complete(b, good)).data.error.code, 'token_expired');
    assert.equal((await complete(a, good, uuid7(), { id_token: 'not-an-input' })).status, 400);
    assert.equal(exchanges, 0);

    const key = uuid7(), linked = await complete(a, good, key);
    assert.equal(linked.status, 200, JSON.stringify(linked.data));
    assert.deepEqual(linked.data.account, { id: a.id, is_guest: false });
    assert.equal(linked.data.identity.email_masked, 'i***@example.invalid');
    assert.doesNotMatch(JSON.stringify(linked.data), new RegExp(subject));
    assert.doesNotMatch(JSON.stringify(linked.data), new RegExp(fakeEmail));
    assert.deepEqual(await complete(a, good, key), { ...linked, replay: 'true' });
    assert.equal((await complete(a, { ...good, code: uuid7() }, key)).data.error.code, 'idempotency_conflict');
    assert.equal((await complete(a, good)).data.error.code, 'token_expired');
    assert.equal(exchanges, 1);
    const rejected = await complete(b, await consent(b));
    assert.equal(rejected.status, 409);
    assert.equal(rejected.data.error.code, 'identity_in_use');
    assert.equal(await db.accounts.count(), beforeAccounts);
    assert.equal((await db.accounts.findUniqueOrThrow({ where: { id: b.id } })).is_guest, true);
    assert.equal(await db.identities.count({ where: { provider: 'google', provider_sub: subject } }), 1);
    assert.equal(await db.abuse_logs.count({ where: { device_hash: a.hash, event: 'google_linked' } }), 1);
    const unlink = await call(prefix, { method: 'DELETE', token: a.token, headers: {
      'device-token': a.credentials.device_token, 'device-proof': a.credentials.device_proof,
    } });
    assert.equal(unlink.status, 409);
    assert.equal(unlink.data.error.code, 'recovery_required');

    const unsigned = await consent(b, { signed: false });
    assert.equal((await complete(b, unsigned)).status, 401);
    assert.equal((await complete(b, unsigned)).data.error.code, 'token_expired');
    const unverified = await consent(b, { claims: { email_verified: false } });
    assert.equal((await complete(b, unverified)).data.error.code, 'google_email_unverified');
    const expired = await consent(b);
    await db.auth_requests.updateMany({ where: { scope: `link-google-state:${sha(expired.state)}` },
      data: { expires_at: new Date(Date.now() - 1) } });
    assert.equal((await complete(b, expired)).data.error.code, 'token_expired');
    assert.equal(exchanges, 4);

    let release;
    const waiting = new Promise((resolve) => { release = resolve; });
    const race = await consent(a, { wait: waiting });
    try {
      const racingKey = uuid7();
      const first = complete(a, race, racingKey);
      const until = Date.now() + 2000;
      while (codes.has(race.code) && Date.now() < until) await new Promise((resolve) => setTimeout(resolve, 5));
      assert.equal(codes.has(race.code), false);
      assert.equal((await complete(a, race, racingKey)).data.error.code, 'request_in_progress');
      assert.equal((await complete(a, race)).data.error.code, 'token_expired');
      release();
      assert.equal((await first).status, 200);
      assert.equal(exchanges, 5);
    } finally { release(); }

    const c = await enroll(a.id);
    assert.equal(c.id, a.id);
    const sessions = await list(a);
    assert.equal(sessions.status, 200);
    assert.equal(sessions.data.length, 2);
    assert.equal(sessions.data.find(({ current }) => current).device_hash_short, a.hash.slice(0, 8));
    assert.doesNotMatch(JSON.stringify(sessions.data), new RegExp(a.hash));
    const foreignId = (await list(b)).data[0].id;
    assert.equal((await revoke(a, `/${foreignId}`)).status, 404);
    const signOutKey = uuid7();
    assert.equal((await revoke(a, '?others=true', signOutKey)).status, 204);
    assert.equal((await revoke(a, '?others=true', signOutKey)).replay, 'true');
    assert.equal((await list(c)).status, 401);
    assert.equal((await call('auth/refresh', { data: { ...c.credentials, refresh_token: c.refresh } })).status, 401);
    assert.equal((await list(b)).status, 200);
    const [current] = (await list(a)).data;
    assert.equal(current.current, true);
    const selfKey = uuid7();
    assert.equal((await revoke(a, `/${current.id}`, signOutKey)).data.error.code, 'idempotency_conflict');
    assert.equal((await revoke(a, `/${current.id}`, selfKey)).status, 204);
    assert.equal((await revoke(a, `/${current.id}`, selfKey)).replay, 'true');
    assert.equal((await list(a)).status, 401);
  } finally { await app.close(); }
});
