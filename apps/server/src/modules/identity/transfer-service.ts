import { Injectable } from '@nestjs/common';
import { PrismaClient, transfer_tokens } from '@prisma/client';
import { createPublicKey, verify as verifySignature } from 'node:crypto';
import { denied, failure, seal, sha, transferToken, unseal, uuid7, verify } from '../auth/credentials';
import { GuestAuth } from '../auth/service';
import { ConsentTx as Tx, EnrollmentInput, consentLock } from './consent-store';

export const transferTtlMs = 120_000;
const rateWindowMs = 180_000;
const replayTtlMs = 604_800_000;
const statusOf = (row: transfer_tokens, now = Date.now()) => row.status !== 'pending' ? row.status :
  row.expires_at.getTime() <= now ? 'expired' : row.used_at ? 'awaiting_confirmation' : 'pending';
const challenge = (row: transfer_tokens) => sha(`hasta/v1/transfer/confirm\n${row.id}\n${row.to_device}`);
const matchCode = (value: string) => value.slice(0, 8).toUpperCase();
const approvalKey = (key: string) => {
  try {
    const parsed = createPublicKey({ key: Buffer.from(key, 'base64url'), format: 'der', type: 'spki' });
    if (parsed.asymmetricKeyType === 'ec' && parsed.asymmetricKeyDetails?.namedCurve === 'prime256v1' &&
        parsed.export({ format: 'der', type: 'spki' }).toString('base64url') === key) return parsed;
  } catch { /* Invalid key; never report request contents. */ }
  throw failure(400, 'validation_failed');
};
const missing = () => failure(404, 'not_found');
const expired = () => failure(410, 'token_expired');
const used = () => failure(409, 'token_used');

@Injectable()
export class DeviceTransfer {
  constructor(private readonly db: PrismaClient, private readonly auth: GuestAuth) {}

  private enabled() {
    if (process.env.HASTA_AUTH_QR_TRANSFER_ENABLED !== 'true') throw missing();
  }

  private async replay<T>(tx: Tx, scope: string, key: string, fp: string, work: () => Promise<T>,
    check?: (reply: T) => Promise<void>, ttlMs = replayTtlMs) {
    await tx.auth_requests.deleteMany({ where: { scope, key, expires_at: { lte: new Date() } } });
    const previous = await tx.auth_requests.findUnique({ where: { scope_key: { scope, key } } });
    const aad = `${scope}:${key}:${fp}`;
    if (previous) {
      if (previous.fingerprint !== fp) throw failure(409, 'idempotency_conflict');
      const reply = unseal(previous.sealed, aad) as T;
      await check?.(reply);
      return { replay: true, reply };
    }
    const reply = await work();
    await tx.auth_requests.create({ data: { scope, key, fingerprint: fp, sealed: seal(reply, aad),
      expires_at: new Date(Date.now() + ttlMs) } });
    return { replay: false, reply };
  }

  private source(row: transfer_tokens | null, actor: { sub: string; hash: string }) {
    if (!row || row.account_id !== actor.sub || row.from_device !== actor.hash || !row.approval_key) throw missing();
    return row;
  }

  private async currentSource(tx: Tx, row: transfer_tokens) {
    const source = await tx.device_bindings.findFirst({ where: { account_id: row.account_id, device_hash: row.from_device,
      revoked_at: null, account: { status: 'active' } }, select: { bound_at: true } });
    if (!source || source.bound_at.getTime() !== row.source_bound_at?.getTime()) throw denied();
  }

  private async vacant(tx: Tx, hash: string) {
    const bound = await tx.device_bindings.findFirst({ where: { device_hash: hash, revoked_at: null },
      select: { account: { select: { is_guest: true } } } });
    if (bound) throw failure(409, bound.account.is_guest ? 'guest_exists_on_target' : 'account_exists_on_target');
  }

  async start(bearer: string, input: EnrollmentInput & { approval_key: string }, key: string) {
    this.enabled();
    approvalKey(input.approval_key);
    return this.db.$transaction(async (tx) => {
      const actor = await this.auth.provedActor(tx, bearer, input, { realOnly: true });
      await this.auth.current(tx, actor);
      const result = await this.replay(tx, `qr-start:${actor.sub}:${actor.hash}`, key, sha(input.approval_key), async () => {
        const now = new Date();
        const since = new Date(now.getTime() - rateWindowMs);
        for (const scope of [{ account_id: actor.sub }, { from_device: actor.hash }]) {
          const window = await tx.transfer_tokens.findMany({ where: { ...scope, created_at: { gt: since } },
            orderBy: { created_at: 'desc' }, take: 2, select: { created_at: true } });
          if (window.length === 2) throw failure(429, 'rate_limited',
            Math.ceil((window[1]!.created_at.getTime() + rateWindowMs - now.getTime()) / 1000));
        }
        const bound = await tx.device_bindings.findUniqueOrThrow({ where: { account_id_device_hash:
          { account_id: actor.sub, device_hash: actor.hash } } });
        const id = uuid7();
        await tx.transfer_tokens.create({ data: {
          id, account_id: actor.sub, from_device: actor.hash, token_hash: sha(transferToken(id)),
          approval_key: input.approval_key, source_bound_at: bound.bound_at, created_at: now,
          expires_at: new Date(now.getTime() + transferTtlMs),
        } });
        return id;
      });
      const row = this.source(await tx.transfer_tokens.findUnique({ where: { id: result.reply } }), actor);
      const state = statusOf(row);
      if (state === 'expired') throw expired();
      if (state !== 'pending') throw used();
      await this.currentSource(tx, row);
      const token = transferToken(row.id);
      if (sha(token) !== row.token_hash) throw expired();
      return { replay: result.replay, reply: {
        transfer_id: row.id, qr_payload: JSON.stringify({ v: 1, token }), expires_at: row.expires_at,
      } };
    });
  }

  async redeem(input: EnrollmentInput & { token: string }, key: string) {
    this.enabled();
    const token_hash = sha(input.token);
    return this.db.$transaction(async (tx) => {
      const target = await this.auth.provedRecoveryDevice(tx, input);
      const hint = await tx.transfer_tokens.findUnique({ where: { token_hash }, select: { account_id: true } });
      if (!hint) throw expired();
      await consentLock(tx, `account:${hint.account_id}`);
      const row = await tx.transfer_tokens.findUnique({ where: { token_hash } });
      if (!row?.approval_key || row.expires_at.getTime() <= Date.now()) throw expired();
      return this.replay(tx, `qr-redeem:${target.hash}`, key, token_hash, async () => {
        if (statusOf(row) !== 'pending') throw used();
        if (row.from_device === target.hash) throw failure(400, 'validation_failed');
        await this.currentSource(tx, row);
        await this.vacant(tx, target.hash);
        const now = new Date();
        if (row.expires_at <= now) throw expired();
        const scanned = await tx.transfer_tokens.update({ where: { id: row.id },
          data: { to_device: target.hash, used_at: now } });
        return { transfer_id: row.id, status: 'awaiting_confirmation', expires_at: row.expires_at,
          match_code: matchCode(challenge(scanned)) };
      }, async () => {
        if (row.to_device !== target.hash || statusOf(row) !== 'awaiting_confirmation') throw used();
      });
    });
  }

  async inspect(bearer: string, id: string) {
    this.enabled();
    const actor = verify('access', bearer);
    return this.db.$transaction(async (tx) => {
      await consentLock(tx, `account:${actor.sub}`);
      await this.auth.current(tx, actor);
      const row = this.source(await tx.transfer_tokens.findUnique({ where: { id } }), actor);
      await this.currentSource(tx, row);
      const status = statusOf(row);
      return { status, expires_at: row.expires_at,
        ...(status === 'awaiting_confirmation' && { approval_challenge: challenge(row), match_code: matchCode(challenge(row)) }) };
    });
  }

  async decide(bearer: string, input: EnrollmentInput & { transfer_id: string }, key: string, signature?: string) {
    this.enabled();
    const id = input.transfer_id.toLowerCase();
    const signed = signature !== undefined;
    return this.db.$transaction(async (tx) => {
      const claims = verify('access', bearer);
      // Always take at most one device lock before the account lock, including opposite transfers.
      const hint = signed ? await tx.transfer_tokens.findFirst({ where: { id, account_id: claims.sub, from_device: claims.hash },
        select: { to_device: true } }) : null;
      if (hint?.to_device) await consentLock(tx, `device:${hint.to_device}`);
      const actor = await this.auth.provedActor(tx, bearer, input, { realOnly: true, lockedTarget: !!hint?.to_device });
      const row = this.source(await tx.transfer_tokens.findUnique({ where: { id } }), actor);
      return this.replay(tx, `qr-${signed ? 'confirm' : 'reject'}:${actor.sub}:${actor.hash}`, key,
        sha(JSON.stringify([id, signature])), async () => {
          await this.auth.current(tx, actor);
          await this.currentSource(tx, row);
          const status = statusOf(row);
          if (status === 'expired') throw expired();
          if (status !== 'pending' && status !== 'awaiting_confirmation') throw used();
          if (!signed) {
            await tx.transfer_tokens.update({ where: { id }, data: { status: 'rejected' } });
            return { status: 'rejected' };
          }
          if (status !== 'awaiting_confirmation' || !row.to_device || hint?.to_device !== row.to_device)
            throw failure(409, 'request_in_progress');
          if (!verifySignature('sha256', Buffer.from(challenge(row)), approvalKey(row.approval_key!),
            Buffer.from(signature, 'base64url'))) throw failure(403, 'biometric_required');
          await this.vacant(tx, row.to_device);
          const enrolled = await tx.device_enrollments.findUnique({ where: { device_hash: row.to_device } });
          if (!enrolled || enrolled.qa_only) throw denied();
          const now = new Date();
          if (row.expires_at <= now) throw expired();
          const revoked_sessions = await this.auth.transferBinding(tx, actor.sub, actor.hash,
            { hash: row.to_device, platform: enrolled.platform }, now);
          await tx.transfer_tokens.update({ where: { id }, data: { status: 'confirmed', target_bound_at: now } });
          return { status: 'confirmed', new_device_bound_at: now, revoked_sessions };
        }, async () => {
          if (!signed) await this.auth.current(tx, actor);
        });
    });
  }

  async claim(input: EnrollmentInput & { transfer_id: string }, key: string) {
    this.enabled();
    const id = input.transfer_id.toLowerCase();
    return this.db.$transaction(async (tx) => {
      const target = await this.auth.provedRecoveryDevice(tx, input);
      const hint = await tx.transfer_tokens.findFirst({ where: { id, to_device: target.hash }, select: { account_id: true } });
      if (!hint) throw missing();
      await consentLock(tx, `account:${hint.account_id}`);
      const row = await tx.transfer_tokens.findFirst({ where: { id, to_device: target.hash } });
      if (!row?.approval_key) throw missing();
      return this.replay(tx, `qr-claim:${target.hash}`, key, sha(id), async () => {
        if (row.expires_at.getTime() <= Date.now()) throw expired();
        if (row.claimed_at || row.status === 'rejected') throw used();
        if (row.status !== 'confirmed' || !row.target_bound_at) throw failure(409, 'request_in_progress');
        const reply = await this.auth.claimTransfer(tx, row.account_id, target.hash, row.target_bound_at);
        await tx.transfer_tokens.update({ where: { id }, data: { claimed_at: new Date() } });
        return reply;
      }, async (prior) => { await this.auth.current(tx, verify('access', prior.access_token)); }, transferTtlMs);
    });
  }
}
