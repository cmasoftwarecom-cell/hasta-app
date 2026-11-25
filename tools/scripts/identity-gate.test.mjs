import assert from 'node:assert/strict';
import { test } from 'node:test';
import { checkIdentityGate } from './identity-gate.mjs';

const identity = 'apps/server/src/modules/identity/';
const source = (path, text) => ({ path, text });
const library = "import { OAuth2Client } from 'google-auth-library';";
const linking = { '/auth/identities/google/link:complete': { post: {} } };
const options = { issuer: 'https://accounts.google.com', audience: 'fixture-client',
  now: 1000, nonce: 'fixture-nonce' };

// Synthetic adapter only. No Google requests, credentials, tokens or app routes.
function verifierWithout(omitted) {
  return async ({ signed, claims, expected }) => {
    const results = {
      signature: signed,
      iss: claims.iss === expected.issuer,
      aud: claims.aud === expected.audience,
      exp: claims.exp > expected.now,
      nonce: claims.nonce === expected.nonce,
      email_verified: claims.email_verified === true,
    };
    if (Object.entries(results).some(([key, valid]) => key !== omitted && !valid)) {
      throw new Error('Fixture evidence rejected');
    }
  };
}

test('T37: valid identity fixture fails the old token ban and passes the new gate', async () => {
  const text = `${library}\n@Controller('v1/auth/identities/google') class Links {
    @Post('link:complete') link(body: { id_token: string }) {}
  }`;
  assert.match(text, /\bid[-_]?token\b/i, 'the previous gate would reject the fixture');
  await checkIdentityGate({
    apiPaths: linking,
    sources: [source(`${identity}link.ts`, text)],
    verification: { verify: verifierWithout(), expected: options },
  });
});

test('T37: identity library alone is allowed inside its module, not elsewhere', async () => {
  await checkIdentityGate({ sources: [source(`${identity}provider.ts`, library)] });
  await assert.rejects(checkIdentityGate({
    sources: [source('apps/server/src/modules/auth/provider.ts', library)],
  }), /identity module/);
});

test('T37: reject documented, undocumented and aliased provider sign-in routes', async () => {
  for (const path of ['/v1/auth/google/signin', '/v1/auth/apple/sign-in',
    '/v1/auth/google/sign_in', '/v1/auth/google/log/in']) {
    await assert.rejects(checkIdentityGate({ apiPaths: { [path]: { post: {} } } }), /sign-in route/);
  }
  await assert.rejects(checkIdentityGate({
    sources: [source(`${identity}controller.ts`, "@Controller('v1/auth/google') class Auth { @Post('sign-in') entry() {} }")],
  }), /sign-in route/);
  await assert.rejects(checkIdentityGate({
    sources: [source(`${identity}controller.ts`, "@Post('session') exchange(idToken: string) {}")],
  }), /non-identity route/);
  await assert.rejects(checkIdentityGate({
    sources: [source(`${identity}controller.ts`, '@Post(route) exchange() {}')],
  }), /static literal/);
  await assert.rejects(checkIdentityGate({
    apiPaths: { '/v1/auth/session': { post: { requestBody: { $ref: '#/components/schemas/Input' } } } },
    apiSchemas: { Input: { properties: { id_token: { type: 'string' } } } },
    verification: { verify: verifierWithout(), expected: options },
  }), /non-identity route/);
});

test('T37: fail closed if a trust surface appears without a behavioural adapter', async () => {
  await assert.rejects(checkIdentityGate({ apiPaths: linking }), /behavioural verifier/);
  await assert.rejects(checkIdentityGate({
    apiPaths: { '/v1/auth/recover:complete': { post: {} } },
  }), /behavioural verifier/);
  await assert.rejects(checkIdentityGate({
    sources: [source(`${identity}link.ts`, 'client.verifyIdToken(input);')],
  }), /behavioural verifier/);
  await assert.rejects(checkIdentityGate({
    apiPaths: { '/v1/auth/session': { post: {} } },
    sources: [source('apps/server/src/modules/auth/dto.ts', 'class Body { id_token: string }')],
    verification: { verify: verifierWithout(), expected: options },
  }), /identity module/);
});

for (const claim of ['signature', 'iss', 'aud', 'exp', 'nonce', 'email_verified']) {
  test(`T37: adapter skipping ${claim} fails`, async () => {
    await assert.rejects(checkIdentityGate({
      apiPaths: linking,
      verification: { verify: verifierWithout(claim), expected: options },
    }), new RegExp(`accepted invalid ${claim}\\b`));
  });
}
