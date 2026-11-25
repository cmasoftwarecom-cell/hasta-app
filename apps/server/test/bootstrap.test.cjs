const assert = require('node:assert/strict');
const { test } = require('node:test');
const { createApp, Database } = require('../dist/main');
const { randomBytes } = require('node:crypto');
const { sha, uuid7 } = require('../dist/modules/auth/credentials');
const { ReplayExpiry } = require('../dist/modules/auth/replay-expiry');

test('S0-SMOKE: Nest HTTP starts; migrated PostgreSQL serves Prisma queries', async () => {
  const database = new URL(process.env.HASTA_DATABASE_URL);
  assert.equal(database.pathname, '/hasta_test', 'use the isolated database');
  const app = await createApp();
  try {
    const prisma = app.get(Database);
    const idle = { scope: 'restart-expired', key: uuid7(), fingerprint: 'fixture', sealed: 'fixture' };
    await prisma.auth_requests.create({ data: { ...idle, expires_at: new Date(Date.now() - 1000) } });
    await app.listen(0, '127.0.0.1');
    assert.equal(await prisma.auth_requests.findUnique({ where: { scope_key: { scope: idle.scope, key: idle.key } } }), null);
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
test('T40/T41/T42/T46: guest lifecycle, device-scoped replays and family revocation', async () => {
  assert.equal(new URL(process.env.HASTA_DATABASE_URL).pathname, '/hasta_test');
  Object.assign(process.env, { HASTA_ENV: 'test', HASTA_QUICK_TEST_ACCOUNTS_ENABLED: 'true',
    HASTA_AUTH_SECRET: randomBytes(32).toString('hex'), HASTA_DEVICE_PEPPER: randomBytes(32).toString('hex'),
    HASTA_ACCESS_TOKEN_TTL_SECONDS: '900', HASTA_REFRESH_TOKEN_TTL_SECONDS: '2592000', HASTA_DEVICE_TOKEN_TTL_SECONDS: '31536000',
    HASTA_DEVICE_REGISTER_PER_HOUR: '10', HASTA_GUEST_CREATE_PER_HOUR: '3', HASTA_DEVICE_COOLDOWN_ENABLED: 'true' });
  const app = await createApp();
  const db = app.get(Database);
  await app.listen(0, '127.0.0.1');
  const url = await app.getUrl();
  const call = async (path, data, key = uuid7(), token = '') => {
    const res = await fetch(`${url}/v1/${path}`, { method: data ? 'POST' : 'GET',
      headers: { 'content-type': 'application/json', 'idempotency-key': key, authorization: `Bearer ${token}` },
      body: data && JSON.stringify(data) });
    return { status: res.status, replay: res.headers.get('idempotent-replayed'), requestId: res.headers.get('x-request-id'),
      retry: res.headers.get('retry-after'), data: res.status === 204 ? null : await res.json() };
  };
  const register = (raw_device_id, device_proof, key) =>
    call('auth/device/register', { raw_device_id, device_proof, platform: 'android', app_version: '1.0.0', os_version: '14' }, key);
  const enroll = async (raw = uuid7(), proof = randomBytes(32).toString('hex'), key) => {
    const result = await register(raw, proof, key);
    assert.equal(result.status, 200);
    return { ...result.data, raw, proof };
  };
  try {
    const enrollmentKey = uuid7(), a = await enroll(uuid7(), randomBytes(32).toString('hex'), enrollmentKey), b = await enroll();
    const guest = (device, key) => call('auth/guest', { device_token: device.device_token, device_proof: device.proof, locale: 'my' }, key);
    const key = uuid7(), first = await guest(a, key);
    assert.equal(first.status, 200); assert.equal(first.data.account.is_guest, true); assert.equal(first.data.is_new_account, true);
    assert.equal((await register(a.raw, b.proof, enrollmentKey)).status, 401);
    assert.equal((await guest({ ...a, proof: b.proof }, key)).status, 401);
    assert.equal((await register(a.raw, a.proof, enrollmentKey)).replay, 'true');
    assert.equal((await guest(a, key)).data.refresh_token, first.data.refresh_token);
    const otherDevice = await guest(b, key);
    assert.notEqual(otherDevice.data.account.id, first.data.account.id);
    const otherFamily = await guest(a);
    assert.equal(otherFamily.data.account.id, first.data.account.id);
    assert.equal((await call('me', null, undefined, first.data.access_token)).data.account.id, first.data.account.id);
    const refresh = (device, refresh_token, idemKey) => call('auth/refresh', { device_token: device.device_token, device_proof: device.proof, refresh_token }, idemKey);
    const rotateKey = uuid7(), rotated = await refresh(a, first.data.refresh_token, rotateKey);
    assert.equal(rotated.status, 200); assert.equal((await refresh(a, first.data.refresh_token, rotateKey)).replay, 'true');
    // A rotated token would trip the reuse guard even without the device check.
    const activeSession = await db.sessions.findUniqueOrThrow({
      where: { refresh_hash: sha(rotated.data.refresh_token) },
    });
    const family = { family_id: activeSession.family_id };
    assert.equal(activeSession.revoked_at, null);
    assert.equal(await db.sessions.count({ where: family }), 2);
    assert.equal((await call('me', null, undefined, rotated.data.access_token)).status, 200);
    const crossDevice = await refresh(b, rotated.data.refresh_token);
    assert.equal(crossDevice.status, 401, 'T46: an active token is rejected on another binding');
    assert.equal(await db.sessions.count({ where: { ...family, revoked_at: null } }), 0,
      'T46: rejection commits revocation of the entire family');
    assert.equal((await refresh(a, rotated.data.refresh_token)).status, 401);
    assert.equal((await refresh(a, first.data.refresh_token, rotateKey)).status, 401);
    assert.equal((await guest(a, key)).status, 401);
    assert.equal((await call('me', null, undefined, rotated.data.access_token)).status, 401);
    assert.equal((await call('me', null, undefined, otherFamily.data.access_token)).status, 200);
    assert.equal((await call('me', null, undefined, otherDevice.data.access_token)).status, 200);
    const c = await enroll();
    await db.device_cooldowns.create({ data: { device_hash: c.device_hash, until: new Date(Date.now() + 60_000) } });
    const blocked = await guest(c);
    assert.equal(blocked.status, 429); assert.equal(blocked.data.error.code, 'device_cooldown');
    assert.equal(blocked.data.error.request_id, blocked.requestId);
    assert.equal(String(blocked.data.error.retry_after_seconds), blocked.retry);
    const exit = { device_token: b.device_token, device_proof: b.proof, everywhere: false };
    const lastKey = uuid7(), last = await guest(b, lastKey), exitKey = uuid7();
    assert.equal((await call('auth/logout', exit, exitKey, last.data.access_token)).status, 204);
    assert.equal((await call('auth/logout', exit, exitKey, last.data.access_token)).replay, 'true');
    assert.equal((await call('me', null, undefined, last.data.access_token)).status, 401);
    assert.equal((await guest(b, lastKey)).status, 401);

    const qa = { device_token: a.device_token, device_proof: a.proof, handle: 'tester.minor', reset: false };
    const minor = await call('qa/guest', qa);
    assert.equal(minor.status, 200);
    const profile = (await call('me', null, undefined, minor.data.access_token)).data.profile;
    assert.equal(new Date().getUTCFullYear() - Number(profile.birth_date.slice(0, 4)), 12);
    const reset = await call('qa/guest', { ...qa, reset: true });
    assert.equal(reset.status, 200);
    assert.notEqual(reset.data.account.id, minor.data.account.id);
    assert.equal((await call('me', null, undefined, minor.data.access_token)).status, 401);
    process.env.HASTA_ENV = 'production';
    assert.equal((await call('qa/guest', qa)).status, 404);
    assert.equal((await call('me', null, undefined, reset.data.access_token)).status, 401);
    process.env.HASTA_ENV = 'test';

    const idle = { scope: 'idle-device', key: uuid7(), fingerprint: 'fixture', sealed: 'fixture' };
    await db.auth_requests.create({ data: { ...idle, expires_at: new Date(Date.now() - 60_000) } });
    assert.equal(await app.get(ReplayExpiry).purge(), 1);
    assert.equal(await db.auth_requests.findUnique({ where: { scope_key: { scope: idle.scope, key: idle.key } } }), null);
    assert.ok(!(JSON.stringify(await db.device_enrollments.findMany())).includes(a.proof));
  } finally {
    try { await db.$transaction([db.auth_requests.deleteMany(), db.device_enrollments.deleteMany(), db.device_cooldowns.deleteMany(), db.abuse_logs.deleteMany(), db.accounts.deleteMany()]); }
    finally { await app.close(); }
  }
});
