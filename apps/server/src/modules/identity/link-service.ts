import { HttpException, Inject, Injectable } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { failure, seal, sha, uuid7, verify } from '../auth/credentials';
import { GuestAuth } from '../auth/service';
import { GoogleOAuth, googleScopes } from './google-oauth';
import { consentLock as lock, consentSeconds as ttlSeconds, ConsentSecret as Intent, ConsentTx as Tx,
  EnrollmentInput as Credentials, loadConsent as load, openConsent as open, storeConsent as save } from './consent-store';

const scopeFor = (state: string) => `link-google-state:${sha(state)}`;
export const GOOGLE_LINK = Symbol('GoogleOAuth for identity consent');
export function googleLinkProvider() {
  let provider: GoogleOAuth | undefined;
  return () => {
    if (process.env.HASTA_AUTH_GOOGLE_LINK_ENABLED !== 'true') throw failure(404, 'not_found');
    return provider ??= new GoogleOAuth({
      clientId: process.env.HASTA_GOOGLE_CLIENT_ID ?? '',
      clientSecret: process.env.HASTA_GOOGLE_CLIENT_SECRET ?? '',
      redirectUri: process.env.HASTA_GOOGLE_REDIRECT_URI ?? '',
    });
  };
}

@Injectable()
export class GoogleLinks {
  constructor(private readonly db: PrismaClient, private readonly auth: GuestAuth,
    @Inject(GOOGLE_LINK) private readonly provider: () => GoogleOAuth) {}

  async status(bearer: string) {
    const account = await this.auth.current(this.db, verify('access', bearer));
    const identity = await this.db.identities.findFirst({
      where: { account_id: account.id, provider: 'google', email_verified: true },
      select: { email: true, linked_at: true },
    });
    return { identity: identity ? { provider: 'google', email_masked: maskEmail(identity.email),
      linked_at: identity.linked_at } : null };
  }

  private async actor(tx: Tx, bearer: string, credentials: Credentials) {
    const actor = await this.auth.provedActor(tx, bearer, credentials, { realOnly: true });
    await this.auth.current(tx, actor);
    return actor;
  }

  async start(bearer: string, credentials: Credentials, key: string) {
    return this.db.$transaction(async (tx) => {
      const actor = await this.actor(tx, bearer, credentials);
      const provider = this.provider();
      const scope = `link-google-start:${actor.sid}`;
      const prior = await load(tx, scope, key);
      if (prior) return { replay: true, reply: open(prior, scope, key, actor.sid) };
      const { state, nonce, codeVerifier, authUrl } = provider.newConsent();
      const reply = { state, nonce, scopes: googleScopes, auth_url: authUrl, expires_in: ttlSeconds };
      await save(tx, scopeFor(state), actor.sid, actor.hash, { nonce, codeVerifier });
      await save(tx, scope, key, actor.sid, reply);
      return { replay: false, reply };
    });
  }

  async complete(bearer: string, input: Credentials & { state: string; code: string }, key: string) {
    type Rejection = { error: { status: number; code: string } };
    type Result = Rejection | { reply: unknown };
    const fingerprint = sha(JSON.stringify([input.state, input.code]));
    const claim = await this.db.$transaction(async (tx) => {
      const actor = await this.actor(tx, bearer, input);
      const provider = this.provider();
      const scope = `link-google-complete:${actor.sid}`;
      const prior = await load(tx, scope, key);
      if (prior) {
        const result = open<Result | null>(prior, scope, key, fingerprint);
        if (!result) throw failure(409, 'request_in_progress');
        return { replay: true as const, result };
      }
      const stateScope = scopeFor(input.state);
      const intent = await load(tx, stateScope, actor.sid);
      if (!intent) throw failure(401, 'token_expired');
      const { nonce, codeVerifier } = open<Intent>(intent, stateScope, actor.sid, actor.hash);
      await tx.auth_requests.delete({ where: { scope_key: { scope: stateScope, key: actor.sid } } });
      await save(tx, scope, key, fingerprint, null);
      return { replay: false as const, actor, provider, scope, nonce, codeVerifier };
    });
    if (claim.replay) return this.outcome(claim.result, true);
    const proof = await claim.provider.exchange(input.code, claim.nonce, claim.codeVerifier).then(
      (identity) => ({ identity }),
      (error: unknown): Rejection => ({
        error: error instanceof HttpException && error.getStatus() === 422
          ? { status: 422, code: 'google_email_unverified' }
          : { status: 401, code: 'unauthenticated' },
      }),
    );
    const result = await this.db.$transaction(async (tx): Promise<Result> => {
      const actor = await this.actor(tx, bearer, input);
      const reservation = await load(tx, claim.scope, key);
      if (!reservation || open(reservation, claim.scope, key, fingerprint) !== null ||
          actor.sid !== claim.actor.sid) throw failure(401, 'token_expired');
      const result = 'identity' in proof ? await this.link(tx, actor, proof.identity) : proof;
      await tx.auth_requests.update({ where: { scope_key: { scope: claim.scope, key } }, data:
        { sealed: seal(result, `${claim.scope}:${key}:${fingerprint}`) } });
      return result;
    });
    return this.outcome(result, false);
  }

  private outcome(result: { reply: unknown } | { error: { status: number; code: string } }, replay: boolean) {
    if ('error' in result) throw failure(result.error.status, result.error.code);
    return { replay, reply: result.reply };
  }

  private async link(tx: Tx, actor: { sub: string; hash: string }, proof: { subject: string; email: string }) {
    await lock(tx, `google-subject:${sha(proof.subject)}`);
    const owner = await tx.identities.findUnique({
      where: { provider_provider_sub: { provider: 'google', provider_sub: proof.subject } },
    });
    const existing = await tx.identities.findFirst({ where: { account_id: actor.sub, provider: 'google' } });
    if ((owner && owner.account_id !== actor.sub) || (existing && existing.provider_sub !== proof.subject)) {
      return { error: { status: 409, code: 'identity_in_use' } };
    }
    const identity = owner
      ? await tx.identities.update({ where: { id: owner.id }, data: { email: proof.email, email_verified: true } })
      : await tx.identities.create({ data: { id: uuid7(), account_id: actor.sub, provider: 'google',
        provider_sub: proof.subject, email: proof.email, email_verified: true } });
    await tx.accounts.update({ where: { id: actor.sub }, data: { is_guest: false } });
    if (!owner) await tx.abuse_logs.create({ data: { device_hash: actor.hash, event: 'google_linked' } });
    return { reply: { identity: { provider: 'google', email_masked: maskEmail(proof.email), linked_at: identity.linked_at },
      account: { id: actor.sub, is_guest: false }, unlocked: ['premium_purchase', 'restore_purchases', 'device_recovery'] } };
  }

  async unlink(bearer: string, credentials: Credentials, key: string) {
    return this.db.$transaction(async (tx) => {
      const actor = await this.actor(tx, bearer, credentials);
      const scope = `link-google-unlink:${actor.sid}`;
      const prior = await load(tx, scope, key);
      if (prior) return { replay: true, reply: open(prior, scope, key, actor.sid) };
      if (await tx.identities.findFirst({ where: { account_id: actor.sub, provider: 'google' } })) {
        // Guest bindings are not a lost-device recovery method. No other
        // recovery provider is enabled for v1.
        throw failure(409, 'recovery_required');
      }
      await save(tx, scope, key, actor.sid, null);
      return { replay: false, reply: null };
    });
  }
}

function maskEmail(email: string | null) {
  const [local, domain] = email?.split('@') ?? [];
  return local && domain ? `${Array.from(local)[0]}***@${domain}` : '***';
}
