const { generateKeyPairSync, sign } = require('node:crypto');
const { OAuth2Client } = require('google-auth-library');
const { verifyGoogleProof } = require('../dist/modules/identity/google-oauth');

const keys = () => generateKeyPairSync('rsa', { modulusLength: 2048 });
const key = keys();
const other = keys();
const publicKey = key.publicKey.export({ type: 'spki', format: 'pem' });
const b64 = (object) => Buffer.from(JSON.stringify(object)).toString('base64url');
const fakeSubject = 'local-fixture-subject';
const fakeEmail = 'identity@example.invalid';

class LocalGoogleClient extends OAuth2Client {
  async getFederatedSignonCertsAsync() {
    return { certs: { 'local-fixture': publicKey }, format: 'PEM' };
  }
}

function signedProof(claims, signed = true) {
  const data = `${b64({ alg: 'RS256', kid: 'local-fixture' })}.${b64({
    iat: Math.floor(Date.now() / 1000) - 1, sub: fakeSubject, email: fakeEmail, ...claims,
  })}`;
  return `${data}.${sign('RSA-SHA256', Buffer.from(data), signed ? key.privateKey : other.privateKey).toString('base64url')}`;
}

function liveVerification() {
  const client = new LocalGoogleClient();
  const expected = { issuer: 'https://accounts.google.com', audience: 'local-client',
    now: Math.floor(Date.now() / 1000) - 1, nonce: 'local-nonce' };
  return {
    expected,
    verify: ({ signed, claims }) => verifyGoogleProof(
      client, signedProof(claims, signed), expected.audience, expected.nonce,
    ),
  };
}

module.exports = { LocalGoogleClient, signedProof, liveVerification, fakeSubject, fakeEmail };
