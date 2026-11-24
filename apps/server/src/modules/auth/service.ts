import { Injectable } from '@nestjs/common';
import { Prisma, PrismaClient, accounts, sessions } from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { denied, failure, issue, pepper, policy, sameDigest, seal, sha, unseal, uuid7, verify } from './credentials';
type Tx = Prisma.TransactionClient;
type Action = 'register' | 'guest' | 'refresh' | 'logout' | 'qa';
type Device = ReturnType<typeof deviceClaims>;
const deviceClaims = (token: string) => verify('device', token);
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
  get qaAllowed() {
    return ['dev', 'test', 'beta'].includes(process.env.HASTA_ENV ?? '') &&
      process.env.HASTA_QUICK_TEST_ACCOUNTS_ENABLED === 'true';
  }

  async write(action: Action, input: Input, key: string, bearer: string) {
    const device: Device = action === 'register' ? {
      hash: pepper(input.raw_device_id!), platform: input.platform as 'android' | 'ios',
    } : deviceClaims(input.device_token!);
    const proofHash = sha(input.device_proof!);
    const actor = action === 'logout' ? verify('access', bearer) : null;
    if (actor && actor.hash !== device.hash) throw denied();
    const scope = `${action}:${device.hash}:${actor?.sub ?? ''}`;
    const fingerprint = sha(JSON.stringify([{
      ...input, raw_device_id: undefined, device_token: undefined, device_proof: undefined,
    }, actor?.sid]));
    return this.db.$transaction(async (tx) => {
      await lock(tx, `device:${device.hash}`);
      const now = new Date();
      await this.proveEnrollment(tx, action, device, proofHash);
      await tx.auth_requests.deleteMany({ where: { scope, expires_at: { lte: now } } });
      const prior = await tx.auth_requests.findUnique({ where: { scope_key: { scope, key } } });
      const aad = `${scope}:${key}:${fingerprint}`;
      if (prior) {
        if (prior.fingerprint !== fingerprint) throw failure(409, 'idempotency_conflict');
        const reply = unseal(prior.sealed, aad) as { access_token?: string; device_token?: string } | null;
        if (reply?.device_token) deviceClaims(reply.device_token);
        if (reply?.access_token) {
          const previous = access(reply.access_token);
          await lock(tx, `account:${previous.sub}`);
          await this.current(tx, previous);
        }
        return { reply, replay: true };
      }
      if (action === 'register' || action === 'guest' || action === 'qa') {
        const since = new Date(now.getTime() - 3_600_000);
        const limit = policy(action === 'register' ? 'DEVICE_REGISTER_PER_HOUR' : 'GUEST_CREATE_PER_HOUR');
        if (await tx.auth_requests.count({ where: { scope, created_at: { gt: since } } }) >= limit)
          throw failure(429, 'rate_limited', 3600);
      }
      const reply = action === 'register' ? {
        device_hash: device.hash, device_token: issue('device', device, policy('DEVICE_TOKEN_TTL_SECONDS')),
        platform: device.platform, registered_at: now,
      } : action === 'qa' ? await this.qa(tx, device, input.handle!, input.reset === 'true', proofHash)
        : action === 'guest' ? await this.guest(tx, device) : action === 'refresh'
        ? await this.rotate(tx, input.refresh_token!, device.hash) : await this.logout(tx, actor!, input.everywhere === 'true');
      if (reply !== false) await tx.auth_requests.create({ data: {
        scope, key, fingerprint, sealed: seal(reply, aad), expires_at: new Date(now.getTime() + 604_800_000),
      } });
      return { reply, replay: false };
    });
  }
  private async proveEnrollment(tx: Tx, action: Action, device: Device, proof_hash: string) {
    const existing = await tx.device_enrollments.findUnique({ where: { device_hash: device.hash } });
    if (existing) {
      if (existing.platform !== device.platform || !sameDigest(existing.proof_hash, proof_hash) ||
        (existing.qa_only && (!this.qaAllowed || action === 'qa'))) throw denied();
      return;
    }
    // No unenrolled binding can be claimed by registering its identifier anew.
    if (action !== 'register' || await tx.device_bindings.findFirst({ where: { device_hash: device.hash } })) throw denied();
    await tx.device_enrollments.create({ data: { device_hash: device.hash, proof_hash, platform: device.platform } });
  }

  private async qa(tx: Tx, enrolled: Device, handle: string, reset: boolean, proof_hash: string) {
    if (!this.qaAllowed) throw failure(404, 'not_found');
    const device = { ...enrolled, hash: pepper(`hasta-qa-fixture\0${enrolled.hash}:${handle}`) };
    await lock(tx, `device:${device.hash}`);
    await tx.device_enrollments.upsert({
      where: { device_hash: device.hash }, update: {},
      create: { device_hash: device.hash, platform: device.platform, proof_hash, qa_only: true },
    });
    const previous = reset ? await binding(tx, device.hash) : null;
    if (previous) {
      await lock(tx, `account:${previous.account_id}`);
      await tx.accounts.delete({ where: { id: previous.account_id } });
    }
    const entry = await this.guest(tx, device, handle);
    return { ...entry, device_token: issue('device', device, policy('DEVICE_TOKEN_TTL_SECONDS')) };
  }

  private async guest(tx: Tx, device: Device, fixture?: string) {
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
      const account = await tx.accounts.create({ data: {
        id: uuid7(), display_name: fixture,
        identities: { create: { id: uuid7(), provider: 'guest', provider_sub: uuid7() } },
        profile: fixture ? { create: {
          display_name: fixture, birth_date: new Date(fixture === 'tester.minor'
            ? `${new Date().getUTCFullYear() - 12}-01-01` : '1995-01-01'),
        } } : undefined,
      } });
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
    const enrolled = await tx.device_enrollments.findUnique({ where: { device_hash: actor.hash } });
    if (!active(row) || row?.account_id !== actor.sub || row.device_hash !== actor.hash || bound?.account.status !== 'active')
      throw denied();
    if (!enrolled || (enrolled.qa_only && !this.qaAllowed)) throw denied();
    return bound.account;
  }
  async me(bearer: string) {
    const a = await this.current(this.db, access(bearer));
    const p = await this.db.profiles.findUnique({ where: { user_id: a.id } });
    return { account: accountView(a), profile: { display_name: p?.display_name ?? a.display_name, username: a.username,
      bio: p?.bio ?? null, avatar_url: null, birth_date: p?.birth_date?.toISOString().slice(0, 10) ?? null },
    identities: [], entitlements: [], flags: { dating_enabled: false, dating_paused: false, premium: false, test_mode_panel: this.qaAllowed } };
  }
}
const access = (token: string) => verify('access', token);
