import assert from 'node:assert/strict';

const identityModule = /^apps\/server\/src\/modules\/identity\//;
const googleLibrary = /['"`]google-auth-library(?:\/[^'"`]+)?['"`]/;
const tokenBoundary = /\b(?:id[_-]?token|verifyIdToken)\b/i;
const signIn = /(?:^|\/)(?:sign|log)[\s_./-]*in(?:$|[/.:])/i;
const completionRoutes = new Set([
  'auth/identities/google/link:complete',
  'auth/recover:complete',
]);
const normalize = (path) => path.trim().replace(/^\/+|\/+$/g, '').toLowerCase();
// OpenAPI declares /v1 as its server URL, whereas Nest may include it in decorators.
const authPath = (path) => normalize(path).replace(/^v1(?:\/|$)/, '');

function nestRoutes(text) {
  // Read literal Nest controller/handler declarations even when OpenAPI omits them.
  const decorators = [...text.matchAll(
    /@(?:(?:\w+)\.)?(Controller|Get|Post|Put|Patch|Delete|All|Head|Options)\s*\(/g,
  )];
  let controller = '';
  return decorators.map(({ 0: declaration, 1: kind, index }) => {
    const args = text.slice(index + declaration.length);
    const literal = /^\s*(['"`])((?:\\\\:|[^'"`\\\r\n])*)\1\s*\)/.exec(args);
    assert.ok(/^\s*\)/.test(args) || (literal && !literal[2].includes('${')),
      'T37: route must use a static literal so the gate can inspect it');
    const path = literal?.[2]?.replace(/\\\\:/g, ':') ?? '';
    if (kind === 'Controller') {
      controller = normalize(path);
      return controller;
    }
    return [controller, normalize(path)].filter(Boolean).join('/');
  });
}

function carriesIdToken(value, schemas, seen = new Set()) {
  if (typeof value === 'string') return tokenBoundary.test(value);
  if (!value || typeof value !== 'object') return false;
  const ref = typeof value.$ref === 'string' &&
    /^#\/components\/schemas\/([^/]+)$/.exec(value.$ref)?.[1];
  if (ref && !seen.has(ref)) {
    seen.add(ref);
    if (carriesIdToken(schemas[ref], schemas, seen)) return true;
  }
  return Object.entries(value).some(([key, field]) =>
    tokenBoundary.test(key) || carriesIdToken(field, schemas, seen));
}

async function checkVerifier({ verify, expected }) {
  assert.equal(typeof verify, 'function', 'T37: missing verifier function');
  assert.ok(expected?.issuer && expected?.audience && expected?.nonce &&
    Number.isFinite(expected?.now), 'T37: verifier expectations must be explicit');
  const claims = {
    iss: expected.issuer,
    aud: expected.audience,
    exp: expected.now + 60,
    nonce: expected.nonce,
    email_verified: true,
  };
  const probe = (signed, overrides = {}) => verify({
    signed, claims: { ...claims, ...overrides }, expected: { ...expected },
  });
  // Positive control: a verifier that rejects everything isn't conformant.
  await probe(true);
  for (const [name, signed, overrides] of [
    ['signature', false, {}],
    ['iss', true, { iss: `${claims.iss}.invalid` }],
    ['aud', true, { aud: `${claims.aud}-invalid` }],
    ['exp', true, { exp: expected.now }],
    ['nonce', true, { nonce: `${claims.nonce}-invalid` }],
    ['email_verified', true, { email_verified: false }],
    ['email_verified', true, { email_verified: 'true' }],
  ]) {
    await assert.rejects(async () => probe(signed, overrides),
      `T37: verifier accepted invalid ${name}`);
  }
}

export async function checkIdentityGate({ apiPaths = {}, apiSchemas = {},
  sources = [], verification } = {}) {
  let needsVerification = tokenBoundary.test(JSON.stringify({ apiPaths, apiSchemas }));
  const checkRoute = (path) => {
    assert.ok(!signIn.test(path), `T37: sign-in route is forbidden (${path})`);
    if (completionRoutes.has(authPath(path))) needsVerification = true;
  };
  for (const [path, route] of Object.entries(apiPaths)) {
    const normalized = normalize(path);
    checkRoute(normalized);
    assert.ok(completionRoutes.has(authPath(normalized)) || !carriesIdToken(route, apiSchemas),
      `T37: raw ID token in a non-identity route (${path})`);
  }
  for (const { path, text } of sources) {
    const inIdentity = identityModule.test(path);
    if (googleLibrary.test(text)) {
      assert.ok(inIdentity, `T37: Google auth library belongs in the identity module (${path})`);
    }
    const routes = nestRoutes(text);
    for (const route of routes) checkRoute(route);
    if (tokenBoundary.test(text)) {
      assert.ok(inIdentity, `T37: raw ID-token input belongs in the identity module (${path})`);
      assert.ok(routes.map(authPath).every((route) => !route || completionRoutes.has(route) ||
        [...completionRoutes].some((completion) => completion.startsWith(`${route}/`))),
      `T37: raw ID token in a non-identity route (${path})`);
      needsVerification = true;
    }
  }
  if (needsVerification) {
    // Completion routes and token boundaries never pass without verification.
    assert.ok(verification, 'T37: trust surface requires a behavioural verifier');
    await checkVerifier(verification);
  }
}
