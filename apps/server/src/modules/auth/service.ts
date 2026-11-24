import { Injectable } from '@nestjs/common';
import { Prisma, PrismaClient, accounts, sessions } from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { denied, failure, issue, pepper, policy, seal, sha, unseal, uuid7, verify } from './credentials';
type Tx = Prisma.TransactionClient;
type Action = 'register' | 'guest' | 'refresh' | 'logout';
type Input = Record<string, string>;
const accountView = ({ id, status, is_guest, display_name, username, created_at }: accounts) =>
  ({ id, status, is_guest, display_name, username, created_at });
const binding = (tx: Tx, hash: string, account_id?: string) =>
  tx.device_bindings.findFirst({ where: { device_hash: hash, account_id, revoked_at: null }, include: { account: true } });
const lock = (tx: Tx, id: string) => tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${id}, 0))`;
const active = (row: sessions | null) => row && !row.revoked_at && row.expires_at > new Date();
const revoke = (tx: Tx, where: Prisma.sessionsWhereInput, reason: string) =>
  tx.sessions.updateMany({ where: { ...where, revoked_at: null }, data: { revoked_at: new Date(), revoked_reason: reason } });
@Injectable()
export class GuestAuth {
  constructor(private readonly db: PrismaClient) {}
  async write(action: Action, input: Input, key: string, bearer: string) {
    const device = action === 'register' ? {
      hash: pepper(input.raw_device_id!), platform: input.platform as 'android' | 'ios',
    } : verify('device', input.device_token!);
    const actor = action === 'logout' ? verify('access', bearer) : null;
    if (actor && actor.hash !== device.hash) throw denied();
    const scope = `${action}:${device.hash}:${actor?.sub ?? ''}`;
    const fingerprint = sha(JSON.stringify([{ ...input, raw_device_id: undefined, device_token: undefined }, actor?.sid]));
    return this.db.$transaction(async (tx) => {
      await lock(tx, `device:${device.hash}`);
      const now = new Date();
      await tx.auth_requests.deleteMany({ where: { scope, expires_at: { lte: now } } });
      const prior = await tx.auth_requests.findUnique({ where: { scope_key: { scope, key } } });
      const aad = `${scope}:${key}:${fingerprint}`;
      if (prior) {
        if (prior.fingerprint !== fingerprint) throw failure(409, 'idempotency_conflict');
        return { reply: unseal(prior.sealed, aad), replay: true };
      }
      if (action === 'register' || action === 'guest') {
        const since = new Date(now.getTime() - 3_600_000);
        const limit = policy(action === 'register' ? 'DEVICE_REGISTER_PER_HOUR' : 'GUEST_CREATE_PER_HOUR');
        if (await tx.auth_requests.count({ where: { scope, created_at: { gt: since } } }) >= limit)
          throw failure(429, 'rate_limited', 3600);
      }
      const reply = action === 'register' ? {
        device_hash: device.hash, device_token: issue('device', device, policy('DEVICE_TOKEN_TTL_SECONDS')),
        platform: device.platform, registered_at: now,
      } : action === 'guest' ? await this.guest(tx, device) : action === 'refresh'
        ? await this.rotate(tx, input.refresh_token!, device.hash) : await this.logout(tx, actor!, input.everywhere === 'true');
      if (reply !== false) await tx.auth_requests.create({ data: {
        scope, key, fingerprint, sealed: seal(reply, aad), expires_at: new Date(now.getTime() + 604_800_000),
      } });
      return { reply, replay: false };
    });
  }
  private async guest(tx: Tx, device: { hash: string; platform: 'android' | 'ios' }) {
    let bound = await binding(tx, device.hash);
    const is_new_account = !bound;
    if (bound) {
      await lock(tx, `account:${bound.account_id}`);
      bound = await binding(tx, device.hash, bound.account_id);
      if (!bound || bound.account.status !== 'active') throw denied();
    } else {
      const cooldown = process.env.HASTA_DEVICE_COOLDOWN_ENABLED === 'false' &&
        ['dev', 'test'].includes(process.env.HASTA_ENV ?? '') ? null :
        await tx.device_cooldowns.findUnique({ where: { device_hash: device.hash } });
      const seconds = Math.ceil(((cooldown?.until.getTime() ?? 0) - Date.now()) / 1000);
      if (seconds > 0) throw failure(429, 'device_cooldown', seconds, { retry_after_days: Math.ceil(seconds / 86400) });
      const account = await tx.accounts.create({ data: { id: uuid7(), identities: {
        create: { id: uuid7(), provider: 'guest', provider_sub: uuid7() },
      } } });
      bound = await tx.device_bindings.create({ data: {
        id: uuid7(), account_id: account.id, device_hash: device.hash, platform: device.platform,
      }, include: { account: true } });
      await tx.abuse_logs.create({ data: { device_hash: device.hash, event: 'guest_created' } });
    }
    return { ...(await this.session(tx, bound.account_id, device.hash)), account: accountView(bound.account),
      device_binding: { id: bound.id, role: bound.role, device_hash: bound.device_hash, bound_at: bound.bound_at }, is_new_account };
  }
  private async session(tx: Tx, account_id: string, device_hash: string, family_id = uuid7()) {
    const id = uuid7();
    const refresh_token = `rt_${randomBytes(32).toString('base64url')}`;
    const expires_in = policy('ACCESS_TOKEN_TTL_SECONDS');
    await tx.sessions.create({ data: { id, account_id, device_hash, family_id, refresh_hash: sha(refresh_token),
      expires_at: new Date(Date.now() + policy('REFRESH_TOKEN_TTL_SECONDS') * 1000) } });
    return { refresh_token, expires_in, access_token: issue('access', { sub: account_id, sid: id, hash: device_hash }, expires_in) };
  }
  private async rotate(tx: Tx, token: string, hash: string) {
    const where = { refresh_hash: sha(token) };
    const first = await tx.sessions.findUnique({ where });
    if (!first) return false;
    await lock(tx, `account:${first.account_id}`);
    const row = await tx.sessions.findUnique({ where });
    if (!row) return false;
    if (row.device_hash !== hash || row.revoked_reason === 'rotated') {
      await revoke(tx, { family_id: row.family_id }, 'reuse');
      return false;
    }
    if (!active(row) || (await binding(tx, hash, row.account_id))?.account.status !== 'active') return false;
    await revoke(tx, { id: row.id }, 'rotated');
    return this.session(tx, row.account_id, hash, row.family_id);
  }
  private async logout(tx: Tx, actor: ReturnType<typeof access>, everywhere: boolean) {
    await lock(tx, `account:${actor.sub}`);
    await this.current(tx, actor);
    await revoke(tx, { account_id: actor.sub, ...(everywhere ? {} : { device_hash: actor.hash }) }, 'logout');
    return null;
  }
  async current(tx: Tx, actor: ReturnType<typeof access>) {
    const row = await tx.sessions.findUnique({ where: { id: actor.sid } });
    const bound = await binding(tx, actor.hash, actor.sub);
    if (!active(row) || row?.account_id !== actor.sub || row.device_hash !== actor.hash || bound?.account.status !== 'active')
      throw denied();
    return bound.account;
  }
  async me(bearer: string) {
    const a = await this.current(this.db, access(bearer));
    const p = await this.db.profiles.findUnique({ where: { user_id: a.id } });
    return { account: accountView(a), profile: { display_name: p?.display_name ?? a.display_name, username: a.username,
      bio: p?.bio ?? null, avatar_url: null, birth_date: p?.birth_date?.toISOString().slice(0, 10) ?? null },
    identities: [], entitlements: [], flags: { dating_enabled: false, dating_paused: false, premium: false, test_mode_panel: false } };
  }
}
const access = (token: string) => verify('access', token);
