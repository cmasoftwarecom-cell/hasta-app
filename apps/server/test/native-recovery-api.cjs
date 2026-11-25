const { createHash, randomBytes } = require('node:crypto');
const { startNativeApi } = require('./native-api.cjs');
const { LocalGoogleClient, signedProof, fakeEmail } = require('./google-proof-fixture.cjs');
const { GoogleOAuth } = require('../dist/modules/identity/google-oauth');
const { Database } = require('../dist/main');
const { uuid7 } = require('../dist/modules/auth/credentials');

const redirectUri = 'https://recovery.example.invalid/auth/recovery/callback';
const config = { clientId: 'native-recovery-fixture', clientSecret: randomBytes(32).toString('base64url'), redirectUri };
const subject = `native-test-${uuid7()}`;
const proofPattern = /^[A-Za-z0-9_-]{43}$/;
const codeMap = new Map();
const openedStates = new Set();
let seeded;
let browserVisits = 0;
let exchanges = 0;

class NativeFixtureClient extends LocalGoogleClient {
  async getToken({ code, codeVerifier, redirect_uri }) {
    exchanges++;
    const row = codeMap.get(code);
    codeMap.delete(code);
    if (!row || redirect_uri !== redirectUri ||
      createHash('sha256').update(codeVerifier).digest('base64url') !== row.challenge) throw new Error('invalid fixture');
    return { tokens: { id_token: row.token } };
  }
}

function mount(app) {
  const db = app.get(Database);
  app.use('/_native/recovery', async (req, res) => {
    res.set({ 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer',
      'Content-Security-Policy': "default-src 'none'; frame-ancestors 'none'; base-uri 'none'" });
    try {
      const path = new URL(req.url, 'http://127.0.0.1');
      if (req.method === 'GET' && path.pathname === '/ready') {
        return res.status(!seeded && await db.accounts.count() === 0 ? 204 : 409).end();
      }
      if (req.method === 'POST' && path.pathname === '/seed') {
        if (seeded) return res.status(409).end();
        seeded = await db.$transaction(async (tx) => {
          const accounts = await tx.accounts.findMany();
          const bindings = await tx.device_bindings.findMany({ where: { revoked_at: null } });
          const sessions = await tx.sessions.findMany({ where: { revoked_at: null } });
          const account = accounts[0], binding = bindings[0];
          if (accounts.length !== 1 || !account.is_guest || bindings.length !== 1 ||
              binding.account_id !== account.id || sessions.length !== 1 ||
              sessions[0].account_id !== account.id) throw new Error('unexpected fixture database');
          await tx.identities.create({ data: { id: uuid7(), account_id: account.id, provider: 'google',
            provider_sub: subject, email: fakeEmail, email_verified: true } });
          await tx.accounts.update({ where: { id: account.id }, data: { is_guest: false } });
          return { account: account.id, oldDevice: binding.device_hash };
        });
        return res.status(204).end();
      }
      if (req.method === 'GET' && path.pathname === '/consent' && seeded) {
        const fields = ['state', 'nonce', 'code_challenge'].map((key) => path.searchParams.getAll(key));
        if (fields.some((values) => values.length !== 1 || !proofPattern.test(values[0])) ||
            openedStates.has(fields[0][0]) || browserVisits !== 0) return res.status(400).end();
        const [[state], [nonce], [challenge]] = fields;
        openedStates.add(state);
        browserVisits++;
        const code = randomBytes(32).toString('base64url');
        codeMap.set(code, { challenge, token: signedProof({ iss: 'https://accounts.google.com',
          aud: config.clientId, nonce, sub: subject, email_verified: true, exp: Math.floor(Date.now() / 1000) + 180 }) });
        return res.type('html').send(`<!doctype html><meta name="viewport" content="width=device-width, initial-scale=1"><title>Recovery fixture</title><a href="intent://callback/complete?state=${state}&amp;code=${code}#Intent;scheme=hasta-recovery-qa;package=app.hasta.mobile;end">Return to Hasta</a>`);
      }
      if (req.method === 'GET' && path.pathname === '/verify' && seeded) {
        const accounts = await db.accounts.findMany();
        const bindings = await db.device_bindings.findMany();
        const sessions = await db.sessions.findMany();
        const active = bindings.find((binding) => binding.revoked_at === null);
        const old = bindings.find((binding) => binding.device_hash === seeded.oldDevice);
        const current = sessions.find((session) => session.revoked_at === null);
        const revoked = sessions.find((session) => session.device_hash === seeded.oldDevice);
        const passed = browserVisits === 1 && exchanges === 1 && accounts.length === 1 &&
          accounts[0].id === seeded.account && accounts[0].is_guest === false &&
          bindings.length === 2 && active?.device_hash !== seeded.oldDevice && active?.account_id === seeded.account &&
          !!old?.revoked_at && sessions.length === 2 &&
          current?.device_hash === active?.device_hash && current?.account_id === seeded.account &&
          !!revoked?.revoked_at && revoked.revoked_reason === 'device_recovery';
        return res.status(passed ? 204 : 409).end();
      }
      return res.status(404).end();
    } catch {
      return res.status(500).end();
    }
  });
}

function startRecoveryFixture(port) {
  const google = new GoogleOAuth(config, new NativeFixtureClient(config));
  return startNativeApi(port, { configure: mount, providerFactory: () => () => google });
}

if (require.main === module) {
  startRecoveryFixture(Number(process.argv[2] ?? '3000')).catch(() => {
    console.error('Native recovery fixture failed to start.');
    process.exitCode = 1;
  });
}

module.exports = { startRecoveryFixture };
