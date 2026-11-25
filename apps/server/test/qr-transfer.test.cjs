const assert = require('node:assert/strict');
const { generateKeyPairSync, randomBytes, sign } = require('node:crypto');
const { test } = require('node:test');
const { createApp, Database } = require('../dist/main');
const { sha, uuid7 } = require('../dist/modules/auth/credentials');
const { startNativeTransferApi } = require('./native-transfer-api.cjs');

test('T25–T29 QR transfer: local HTTP, native-shaped signatures and committed DB assertions', async () => {
  const database = new URL(process.env.HASTA_DATABASE_URL);
  assert.equal(database.pathname, '/hasta_test');
  assert.equal(database.hostname, '127.0.0.1');
  Object.assign(process.env, { HASTA_ENV: 'test', HASTA_AUTH_QR_TRANSFER_ENABLED: 'false',
    HASTA_AUTH_SECRET: randomBytes(32).toString('hex'), HASTA_DEVICE_PEPPER: randomBytes(32).toString('hex'),
    HASTA_ACCESS_TOKEN_TTL_SECONDS: '900', HASTA_REFRESH_TOKEN_TTL_SECONDS: '2592000',
    HASTA_DEVICE_TOKEN_TTL_SECONDS: '31536000', HASTA_DEVICE_REGISTER_PER_HOUR: '10',
    HASTA_GUEST_CREATE_PER_HOUR: '3' });
  const app = await startNativeTransferApi(0);
  const normal = await createApp();
  const otherListener = await createApp(undefined, { localQrQa: true });
  const db = app.get(Database);
  try {
    await normal.listen(0, '127.0.0.1');
    await otherListener.listen(0, '127.0.0.2');
    const url = await app.getUrl();
    const normalUrl = await normal.getUrl();
    const call = async (path, body, bearer, key = uuid7(), base = url) => {
      const res = await fetch(`${base}/v1/${path}`, { method: body ? 'POST' : 'GET', headers: {
        'content-type': 'application/json', 'idempotency-key': key, ...(bearer ? { authorization: `Bearer ${bearer}` } : {}),
      }, body: body && JSON.stringify(body) });
      return { status: res.status, replay: res.headers.get('idempotent-replayed'),
        retryAfter: res.headers.get('retry-after'), data: await res.json() };
    };
    const enroll = async () => {
      const device_proof = randomBytes(32).toString('hex');
      const res = await call('auth/device/register', { raw_device_id: uuid7(), device_proof,
        platform: 'android', app_version: '1.0.0', os_version: '14' });
      assert.equal(res.status, 200);
      return { creds: { device_token: res.data.device_token, device_proof }, hash: res.data.device_hash };
    };
    const keys = () => {
      const { publicKey, privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
      return { approval_key: publicKey.export({ format: 'der', type: 'spki' }).toString('base64url'),
        sign: (c) => sign('sha256', Buffer.from(c), privateKey).toString('base64url') };
    };
    const qr = 'auth/transfer/';
    const guest = (dev) => call('auth/guest', { ...dev.creds, locale: 'en' });
    const status = (id, bearer) => call(qr + id, undefined, bearer);
    const redeem = (dev, token, key) => call(qr + 'redeem', { ...dev.creds, token }, undefined, key);
    const claim = (dev, transfer_id, key) => call(qr + 'claim', { ...dev.creds, transfer_id }, undefined, key);
    const err = (response, status, code) => {
      assert.equal(response.status, status);
      assert.equal(response.data.error?.code, code);
    };
    const [old, fresh, other, occupied, late] = await Promise.all(Array.from({ length: 5 }, enroll));
    const first = (await guest(old)).data, second = (await guest(old)).data;
    const occupiedEntry = (await guest(occupied)).data;
    const actor = first.access_token;
    const approval = keys();
    const start = (key, approval_key = approval.approval_key) => call(qr + 'start', { ...old.creds, approval_key }, actor, key);
    const confirm = (transfer_id, approval_signature, key) =>
      call(qr + 'confirm', { ...old.creds, transfer_id, approval_signature }, actor, key);
    err(await start(), 404, 'not_found');
    process.env.HASTA_AUTH_QR_TRANSFER_ENABLED = 'true';
    // P0-QR-ROLLOUT-GATE / T27: a flag alone cannot activate the HTTP surface.
    const blockedId = uuid7();
    // Syntactically valid requests must be gated before authentication or lookup.
    const noDevice = { device_token: 'dt_invalid', device_proof: '0'.repeat(64) };
    const denyAll = async (base) => {
      const calls = [
        ['start', { ...old.creds, approval_key: approval.approval_key }, actor],
        ['redeem', { ...noDevice, token: `tt_${'A'.repeat(43)}` }],
        ['confirm', { ...noDevice, transfer_id: blockedId, approval_signature: approval.sign('fixture') }],
        ['reject', { ...noDevice, transfer_id: blockedId }],
        ['claim', { ...noDevice, transfer_id: blockedId }],
        [blockedId],
      ];
      for (const [path, body, bearer] of calls) err(await call(qr + path, body, bearer, undefined, base), 404, 'not_found');
    };
    const originalDatabase = process.env.HASTA_DATABASE_URL;
    try {
      await denyAll(normalUrl);
      await denyAll(await otherListener.getUrl());
      for (const env of ['production', 'staging', 'beta']) {
        process.env.HASTA_ENV = env;
        await denyAll(url);
      }
      process.env.HASTA_ENV = 'test';
      for (const invalidDatabase of ['not-a-url', 'postgresql://db.invalid/hasta_test',
        originalDatabase.replace('/hasta_test', '/hasta'), `${originalDatabase}?schema=public`]) {
        process.env.HASTA_DATABASE_URL = invalidDatabase;
        await denyAll(url);
      }
    } finally {
      process.env.HASTA_ENV = 'test';
      process.env.HASTA_DATABASE_URL = originalDatabase;
    }
    assert.equal(await db.transfer_tokens.count(), 0, 'blocked calls must not create transfer rows');
    const startKey = uuid7();
    const started = await start(startKey);
    assert.equal(started.status, 200);
    assert.deepEqual(await start(startKey), { ...started, replay: 'true' });
    err(await start(startKey, keys().approval_key), 409, 'idempotency_conflict');
    const { transfer_id: id, qr_payload: payload } = started.data;
    const { v, token } = JSON.parse(payload);
    assert.equal(v, 1);
    const row = await db.transfer_tokens.findUniqueOrThrow({ where: { id } });
    assert.equal(row.expires_at - row.created_at, 120_000);
    assert.equal(row.token_hash, sha(token));
    assert.ok(!JSON.stringify(row).includes(token));
    const receipt = await db.auth_requests.findFirstOrThrow({ where: { key: startKey } });
    const { unseal } = require('../dist/modules/auth/credentials');
    assert.equal(unseal(receipt.sealed, `${receipt.scope}:${receipt.key}:${receipt.fingerprint}`), id);
    const rejected = await start();
    const limited = await start();
    err(limited, 429, 'rate_limited');
    assert.ok(Number(limited.retryAfter) > 120);
    const rejectionId = rejected.data.transfer_id;
    const rejectKey = uuid7(), rejectBody = { ...old.creds, transfer_id: rejectionId };
    const rejection = await call(qr + 'reject', rejectBody, actor, rejectKey);
    assert.equal(rejection.data.status, 'rejected');
    assert.deepEqual(await call(qr + 'reject', rejectBody, actor, rejectKey), { ...rejection, replay: 'true' });
    err(await redeem(fresh, JSON.parse(rejected.data.qr_payload).token), 409, 'token_used');
    err(await status(id, occupiedEntry.access_token), 404, 'not_found');
    err(await confirm(id, approval.sign('not scanned')), 409, 'request_in_progress');
    err(await redeem(occupied, token), 409, 'guest_exists_on_target'); // T29
    err(await redeem({ creds: { ...fresh.creds, device_proof: other.creds.device_proof } }, token), 401, 'unauthenticated');

    // T26: simultaneous redemptions, different installations and keys; exactly one wins.
    const contenders = [fresh, other].map((dev) => ({ dev, key: uuid7() }));
    const results = await Promise.all(contenders.map(({ dev, key }) => redeem(dev, token, key)));
    assert.deepEqual(results.map((r) => r.status).sort(), [200, 409]);
    const win = results.findIndex((r) => r.status === 200);
    const { dev: target, key: redeemKey } = contenders[win];
    assert.equal(results[1 - win].data.error.code, 'token_used');
    err(await redeem(target, token), 409, 'token_used');
    assert.deepEqual(await redeem(target, token, redeemKey), { ...results[win], replay: 'true' });
    err(await claim(contenders[1 - win].dev, id), 404, 'not_found');
    err(await claim(target, id), 409, 'request_in_progress'); // T27
    const waiting = await status(id, actor);
    assert.equal(waiting.data.status, 'awaiting_confirmation');
    const c = waiting.data.approval_challenge;
    assert.match(waiting.data.match_code, /^[0-9A-F]{8}$/);
    assert.equal(waiting.data.match_code, results[win].data.match_code);
    err(await confirm(id, keys().sign(c)), 403, 'biometric_required');
    err(await call(qr + 'confirm', { ...old.creds, transfer_id: id, biometric_verified: true }, actor),
      400, 'validation_failed');
    assert.equal((await call('me', undefined, actor)).status, 200);
    assert.equal(await db.device_bindings.count({ where: { device_hash: target.hash, revoked_at: null } }), 0);

    const confirmKey = uuid7(), signature = approval.sign(c);
    const accountCount = await db.accounts.count();
    // Transfer bypasses creation cooldown, without removing it.
    await db.device_cooldowns.create({ data: { device_hash: target.hash, until: new Date(Date.now() + 60_000) } });
    const confirmed = await confirm(id, signature, confirmKey);
    assert.equal(confirmed.status, 200);
    assert.equal(confirmed.data.revoked_sessions, 2);
    assert.deepEqual(await confirm(id, signature, confirmKey), { ...confirmed, replay: 'true' });
    assert.equal(await db.device_bindings.count({ where: { device_hash: old.hash, revoked_at: null } }), 0);
    assert.equal(await db.sessions.count({ where: { account_id: first.account.id, revoked_reason: 'transfer' } }), 2);
    for (const entry of [first, second]) {
      err(await call('me', undefined, entry.access_token), 401, 'unauthenticated');
      err(await call('auth/refresh', { ...old.creds, refresh_token: entry.refresh_token }), 401, 'unauthenticated');
    }
    const claimKey = uuid7();
    const claimed = await claim(target, id, claimKey);
    assert.equal(claimed.status, 200);
    assert.equal(claimed.data.account.id, first.account.id);
    assert.equal(claimed.data.account.is_guest, true);
    assert.equal(claimed.data.is_new_account, false);
    assert.equal(await db.accounts.count(), accountCount);
    assert.deepEqual(await claim(target, id, claimKey), { ...claimed, replay: 'true' });
    err(await claim(target, id), 409, 'token_used');
    assert.equal((await call('me', undefined, claimed.data.access_token)).status, 200);
    assert.equal((await call('me', undefined, occupiedEntry.access_token)).status, 200);

    // Separate source fixtures avoid the live 3-minute rate window.
    const source2 = await enroll();
    const actor2 = (await guest(source2)).data.access_token;
    const start2 = () => call(qr + 'start', { ...source2.creds, approval_key: approval.approval_key }, actor2);
    const expire = (id) => db.transfer_tokens.update({ where: { id }, data: { expires_at: new Date(Date.now() - 1) } });
    const stale = (await start2()).data;
    await expire(stale.transfer_id);
    assert.equal((await status(stale.transfer_id, actor2)).data.status, 'expired');
    err(await redeem(late, JSON.parse(stale.qr_payload).token), 410, 'token_expired'); // T25
    const occupiedLate = (await start2()).data;
    assert.equal((await redeem(late, JSON.parse(occupiedLate.qr_payload).token)).status, 200);
    const c2 = (await status(occupiedLate.transfer_id, actor2)).data.approval_challenge;
    assert.equal((await guest(late)).status, 200);
    const confirm2 = () => call(qr + 'confirm', { ...source2.creds, transfer_id: occupiedLate.transfer_id,
      approval_signature: approval.sign(c2) }, actor2);
    err(await confirm2(), 409, 'guest_exists_on_target'); // Recheck under target lock, not only during scan.
    await expire(occupiedLate.transfer_id);
    err(await confirm2(), 410, 'token_expired');
    assert.equal((await call('me', undefined, actor2)).status, 200);
  } finally {
    await Promise.all([app.close(), normal.close(), otherListener.close()]);
  }
});
