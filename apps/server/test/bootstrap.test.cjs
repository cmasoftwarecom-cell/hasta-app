const assert = require('node:assert/strict');
const { test } = require('node:test');
const { createApp, Database } = require('../dist/main');
const { randomBytes } = require('node:crypto');
const { uuid7 } = require('../dist/modules/auth/credentials');

test('S0-SMOKE: Nest HTTP starts; migrated PostgreSQL serves Prisma queries', async () => {
  const database = new URL(process.env.HASTA_DATABASE_URL);
  assert.equal(database.pathname, '/hasta_test', 'use the isolated database');
  const app = await createApp();
  try {
    const prisma = app.get(Database);
    await app.listen(0, '127.0.0.1');
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
  Object.assign(process.env, { HASTA_AUTH_SECRET: randomBytes(32).toString('hex'), HASTA_DEVICE_PEPPER: randomBytes(32).toString('hex'),
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
    return { status: res.status, replay: res.headers.get('idempotent-replayed'), data: res.status === 204 ? null : await res.json() };
  };
  const register = (raw_device_id) => call('auth/device/register', { raw_device_id, platform: 'android', app_version: '1.0.0', os_version: '14' });
  try {
    const a = (await register(uuid7())).data, b = (await register(uuid7())).data;
    const guest = (device_token, key) => call('auth/guest', { device_token, locale: 'my' }, key);
    const key = uuid7(), first = await guest(a.device_token, key);
    assert.equal(first.status, 200); assert.equal(first.data.account.is_guest, true); assert.equal(first.data.is_new_account, true);
    assert.equal((await guest(a.device_token, key)).data.refresh_token, first.data.refresh_token);
    assert.notEqual((await guest(b.device_token, key)).data.account.id, first.data.account.id);
    assert.equal((await guest(a.device_token)).data.account.id, first.data.account.id);
    assert.equal((await call('me', null, undefined, first.data.access_token)).data.account.id, first.data.account.id);
    const refresh = (device_token, refresh_token, idemKey) => call('auth/refresh', { device_token, refresh_token }, idemKey);
    const rotateKey = uuid7(), rotated = await refresh(a.device_token, first.data.refresh_token, rotateKey);
    assert.equal(rotated.status, 200); assert.equal((await refresh(a.device_token, first.data.refresh_token, rotateKey)).replay, 'true');
    assert.equal((await refresh(b.device_token, first.data.refresh_token, rotateKey)).status, 401);
    assert.equal((await refresh(a.device_token, rotated.data.refresh_token)).status, 401);
    assert.equal((await call('me', null, undefined, rotated.data.access_token)).status, 401);
    const c = (await register(uuid7())).data;
    await db.device_cooldowns.create({ data: { device_hash: c.device_hash, until: new Date(Date.now() + 60_000) } });
    const blocked = await guest(c.device_token);
    assert.equal(blocked.status, 429); assert.equal(blocked.data.error.code, 'device_cooldown');
    const exit = { device_token: b.device_token, everywhere: false };
    const last = await guest(b.device_token), exitKey = uuid7();
    assert.equal((await call('auth/logout', exit, exitKey, last.data.access_token)).status, 204);
    assert.equal((await call('auth/logout', exit, exitKey, last.data.access_token)).replay, 'true');
    assert.equal((await call('me', null, undefined, last.data.access_token)).status, 401);
  } finally {
    try { await db.$transaction([db.auth_requests.deleteMany(), db.device_cooldowns.deleteMany(), db.abuse_logs.deleteMany(), db.accounts.deleteMany()]); }
    finally { await app.close(); }
  }
});
