import { createHash, randomBytes } from 'node:crypto';
import { CodeChallengeMethod, OAuth2Client } from 'google-auth-library';
import { denied, failure } from '../auth/credentials';

const issuers = new Set(['https://accounts.google.com', 'accounts.google.com']);
export const googleScopes = Object.freeze(['openid', 'email', 'profile']);
const proof = () => randomBytes(32).toString('base64url');
const validProof = /^[A-Za-z0-9_-]{43}$/;

export async function verifyGoogleProof(
  client: OAuth2Client, token: string, audience: string, nonce: string,
) {
  if (!token || !audience || !nonce) throw denied();
  const payload = await client.verifyIdToken({ idToken: token, audience })
    .then((ticket) => ticket.getPayload(), () => { throw denied(); });
  if (!payload || !issuers.has(payload.iss) || payload.aud !== audience ||
      !Number.isSafeInteger(payload.exp) || payload.exp <= Math.floor(Date.now() / 1000) ||
      payload.nonce !== nonce || typeof payload.sub !== 'string' ||
      !payload.sub || payload.sub.length > 255) throw denied();
  if (payload.email_verified !== true || typeof payload.email !== 'string' ||
      !payload.email || payload.email.length > 320) throw failure(422, 'google_email_unverified');
  return { subject: payload.sub, email: payload.email };
}

type GoogleConfig = { clientId: string; clientSecret: string; redirectUri: string };

// Server-only primitives. The route layer must persist and consume the intent
// against the originating session/device before passing code to this adapter.
export class GoogleOAuth {
  private readonly client: OAuth2Client;
  private readonly audience: string;
  private readonly redirectUri: string;

  constructor(config: GoogleConfig, client?: OAuth2Client) {
    const callback = URL.canParse(config.redirectUri) ? new URL(config.redirectUri) : null;
    if (!config.clientId || !config.clientSecret || !callback ||
        callback.protocol !== 'https:' || callback.username || callback.password ||
        callback.hash || callback.search) throw failure(503, 'unavailable');
    this.audience = config.clientId;
    this.redirectUri = config.redirectUri;
    this.client = client ?? new OAuth2Client({
      ...config, transporterOptions: { timeout: 5000, retry: false },
    });
  }

  newConsent() {
    const state = proof(), nonce = proof(), codeVerifier = proof();
    const authUrl = this.client.generateAuthUrl({
      client_id: this.audience, redirect_uri: this.redirectUri,
      response_type: 'code', access_type: 'online', scope: [...googleScopes], state, nonce,
      code_challenge: createHash('sha256').update(codeVerifier).digest('base64url'),
      code_challenge_method: CodeChallengeMethod.S256,
    });
    return { state, nonce, codeVerifier, authUrl };
  }

  async exchange(code: string, nonce: string, codeVerifier: string) {
    if (!code || code.length > 2048 || !validProof.test(nonce) || !validProof.test(codeVerifier)) {
      throw failure(400, 'validation_failed');
    }
    const { tokens } = await this.client.getToken({
      code, codeVerifier, redirect_uri: this.redirectUri,
    }).catch(() => { throw denied(); });
    if (!tokens.id_token) throw denied();
    return verifyGoogleProof(this.client, tokens.id_token, this.audience, nonce);
  }
}
