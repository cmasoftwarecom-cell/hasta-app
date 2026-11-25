import { HttpException, Inject, Injectable } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { failure, seal, sha, verify } from '../auth/credentials';
import { GuestAuth } from '../auth/service';
import { GoogleOAuth } from './google-oauth';
import { GOOGLE_LINK } from './link-service';
import { ConsentInput, ConsentSecret, ConsentTx, EnrollmentInput, consentLock, consentSeconds,
  loadConsent, openConsent, storeConsent } from './consent-store';

type RecoveryError = { error: { status: number; code: string } };
type RecoveryResult = Awaited<ReturnType<GuestAuth['restoreOnDevice']>> | RecoveryError;

@Injectable()
export class GmailRecovery {
  constructor(private readonly db: PrismaClient, private readonly auth: GuestAuth,
    @Inject(GOOGLE_LINK) private readonly provider: () => GoogleOAuth) {}

  async start(input: EnrollmentInput, key: string) {
    const provider = this.provider();
    return this.db.$transaction(async (tx) => {
      const { hash } = await this.auth.provedRecoveryDevice(tx, input);
      const scope = `recover-google-start:${hash}`, stateScope = `recover-google-state:${hash}`;
      const prior = await loadConsent(tx, scope, key);
      if (prior) return { replay: true, reply: openConsent(prior, scope, key, hash) };
      if (await tx.auth_requests.findFirst({ where: { scope: stateScope, expires_at: { gt: new Date() } },
        select: { key: true } })) throw failure(409, 'request_in_progress');
      const { state, nonce, codeVerifier, authUrl } = provider.newConsent();
      const reply = { state, nonce, auth_url: authUrl, expires_in: consentSeconds };
      await storeConsent(tx, stateScope, key, sha(state), { nonce, codeVerifier });
      await storeConsent(tx, scope, key, hash, reply);
      return { replay: false, reply };
    });
  }

  async complete(input: ConsentInput, key: string) {
    const provider = this.provider();
    const stateHash = sha(input.state);
    const fingerprint = sha(JSON.stringify([input.state, input.code]));
    const claim = await this.db.$transaction(async (tx) => {
      const { hash } = await this.auth.provedRecoveryDevice(tx, input);
      const scope = `recover-google-complete:${hash}`;
      const prior = await loadConsent(tx, scope, key);
      if (prior) {
        const result = openConsent<RecoveryResult | null>(prior, scope, key, fingerprint);
        if (!result) throw failure(409, 'request_in_progress');
        if ('reply' in result && result.reply) {
          const session = verify('access', result.reply.access_token);
          await consentLock(tx, `account:${session.sub}`);
          await this.auth.current(tx, session);
        }
        return { replay: true as const, result };
      }
      const stateScope = `recover-google-state:${hash}`;
      const intent = await tx.auth_requests.findFirst({ where: { scope: stateScope, fingerprint: stateHash,
        expires_at: { gt: new Date() } }, select: { key: true, sealed: true, fingerprint: true } });
      if (!intent) throw failure(401, 'token_expired');
      const secret = openConsent<ConsentSecret>(intent, stateScope, intent.key, stateHash);
      const consumed = await tx.auth_requests.deleteMany({ where: { scope: stateScope, key: intent.key,
        expires_at: { gt: new Date() } } });
      if (consumed.count !== 1) throw failure(401, 'token_expired');
      await storeConsent(tx, scope, key, fingerprint, null);
      return { replay: false as const, scope, secret };
    });
    if (claim.replay) return this.reply(claim.result, true);
    const proof = await provider.exchange(input.code, claim.secret.nonce, claim.secret.codeVerifier).then(
      ({ subject }) => ({ subject }),
      (error: unknown): RecoveryError => ({ error: error instanceof HttpException && error.getStatus() === 422
        ? { status: 422, code: 'google_email_unverified' } : { status: 401, code: 'unauthenticated' } }),
    );
    const result = await this.db.$transaction(async (tx): Promise<RecoveryResult> => {
      const device = await this.auth.provedRecoveryDevice(tx, input);
      const row = await loadConsent(tx, claim.scope, key);
      if (!row || openConsent(row, claim.scope, key, fingerprint) !== null) throw failure(401, 'token_expired');
      const result = 'subject' in proof ? await this.restore(tx, device, proof.subject) : proof;
      await tx.auth_requests.update({ where: { scope_key: { scope: claim.scope, key } },
        data: { sealed: seal(result, `${claim.scope}:${key}:${fingerprint}`) } });
      return result;
    });
    return this.reply(result, false);
  }

  private async restore(tx: ConsentTx, device: Awaited<ReturnType<GuestAuth['provedRecoveryDevice']>>, subject: string) {
    const where = { provider_provider_sub: { provider: 'google' as const, provider_sub: subject } };
    const hint = await tx.identities.findUnique({ where, select: { account_id: true } });
    const missing = { error: { status: 404, code: 'not_found' } };
    if (!hint) return missing;
    await consentLock(tx, `account:${hint.account_id}`);
    const linked = await tx.identities.findUnique({ where, include: { account: true } });
    if (!linked?.email_verified || linked.account_id !== hint.account_id || linked.account.is_guest ||
        linked.account.status !== 'active') return missing;
    return this.auth.restoreOnDevice(tx, linked.account, device);
  }

  private reply(result: RecoveryResult, replay: boolean) {
    if (result.error) throw failure(result.error.status, result.error.code);
    return { reply: result.reply, replay };
  }
}
