const { startNativeApi } = require('./native-api.cjs');

// A disposable, otherwise empty database is required. Never return row data.
async function startNativeTransferApi(port) {
  let source;
  const { Database } = require('../dist/main');
  return startNativeApi(port, {
    configure(app) {
      const db = app.get(Database);
      const http = app.getHttpAdapter();
      http.post('/_native/transfer/ready', async (_request, response) => {
        try {
          const rows = await db.device_bindings.findMany({ where: { revoked_at: null },
            select: { account_id: true, device_hash: true } });
          if (source || rows.length !== 1 || await db.accounts.count() !== 1 ||
              await db.transfer_tokens.count() !== 0 || await db.sessions.count() !== 1 ||
              await db.sessions.count({ where: { ...rows[0], revoked_at: null } }) !== 1) {
            return response.status(409).end();
          }
          source = rows[0];
          return response.status(204).end();
        } catch { return response.status(500).end(); }
      });
      http.get('/_native/transfer/verify', async (_request, response) => {
        try {
          if (!source || await db.accounts.count() !== 1) return response.status(409).end();
          const old = await db.device_bindings.findFirst({ where: source });
          const target = await db.device_bindings.findFirst({ where: { account_id: source.account_id,
            device_hash: { not: source.device_hash }, revoked_at: null } });
          const moved = await db.transfer_tokens.findFirst({ where: { account_id: source.account_id,
            from_device: source.device_hash, to_device: target?.device_hash, status: 'confirmed',
            used_at: { not: null }, claimed_at: { not: null } } });
          const [activeOld, revokedOld, activeTarget, activeBindings] = await Promise.all([
            db.sessions.count({ where: { ...source, revoked_at: null } }),
            db.sessions.count({ where: { ...source, revoked_reason: 'transfer', revoked_at: { not: null } } }),
            db.sessions.count({ where: { account_id: source.account_id, device_hash: target?.device_hash, revoked_at: null } }),
            db.device_bindings.count({ where: { account_id: source.account_id, revoked_at: null } }),
          ]);
          return response.status(old?.revoked_at && target && moved && activeOld === 0 &&
            revokedOld === 1 && activeTarget >= 1 && activeBindings === 1 ? 204 : 409).end();
        } catch { return response.status(500).end(); }
      });
    },
  });
}

if (require.main === module) {
  process.env.HASTA_AUTH_QR_TRANSFER_ENABLED = 'true';
  process.env.HASTA_AUTH_GOOGLE_LINK_ENABLED = 'false';
  startNativeTransferApi(Number(process.argv[2])).catch(() => {
    console.error('Native transfer QA requires a valid loopback port and isolated test database.');
    process.exitCode = 1;
  });
}

module.exports = { startNativeTransferApi };
