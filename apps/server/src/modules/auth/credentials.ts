import { createCipheriv, createDecipheriv, createHash, createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import { HttpException } from '@nestjs/common';
export const sha = (value: string) => createHash('sha256').update(value).digest('hex');
export const sameDigest = (a: string, b: string) =>
  a.length === b.length && timingSafeEqual(Buffer.from(a, 'hex'), Buffer.from(b, 'hex'));
export const uuidPattern = /^[\da-f]{8}-[\da-f]{4}-7[\da-f]{3}-[89ab][\da-f]{3}-[\da-f]{12}$/i;
export function uuid7() {
  const b = randomBytes(16);
  b.writeUIntBE(Date.now(), 0, 6);
  b[6] = (b[6]! & 15) | 112;
  b[8] = (b[8]! & 63) | 128;
  return b.toString('hex').replace(/^(.{8})(.{4})(.{4})(.{4})/, '$1-$2-$3-$4-');
}
export function failure(status: number, code: string, seconds: number | null = null, details = {}) {
  return new HttpException({ code, seconds, details }, status);
}
export const denied = () => failure(401, 'unauthenticated');
const key = (name: string) => {
  const value = process.env[name];
  if (!value || !/^[\da-f]{64}$/i.test(value)) throw failure(503, 'unavailable');
  return Buffer.from(value, 'hex');
};
export const pepper = (raw: string) => createHmac('sha256', key('HASTA_DEVICE_PEPPER')).update(raw).digest('hex');
export const policy = (name: string) => {
  const value = Number(process.env[`HASTA_${name}`]);
  if (!Number.isSafeInteger(value) || value < 1 || value > 31_536_000) throw failure(503, 'unavailable');
  return value;
};
type Device = { hash: string; platform: 'android' | 'ios' };
type Access = { sub: string; sid: string; hash: string };
const header = Buffer.from('{"alg":"HS256","typ":"JWT"}').toString('base64url');
const derived = (use: string) => createHmac('sha256', key('HASTA_AUTH_SECRET')).update(`hasta/v1/${use}`).digest();
const signature = (use: string, data: string) => createHmac('sha256', derived(use)).update(data).digest();
// Deterministic only for idempotent start replay. No QR secret is persisted or sealed.
export const transferToken = (id: string) => `tt_${signature('qr-device-transfer', id).toString('base64url')}`;
export function issue(kind: 'device' | 'access', data: Device | Access, seconds: number) {
  const payload = Buffer.from(JSON.stringify({ ...data, exp: Math.floor(Date.now() / 1000) + seconds })).toString('base64url');
  const body = `${header}.${payload}`;
  return `${kind === 'device' ? 'dt_' : ''}${body}.${signature(kind, body).toString('base64url')}`;
}
export function verify(kind: 'device', token: string): Device;
export function verify(kind: 'access', token: string): Access;
export function verify(kind: 'device' | 'access', token: string): Device | Access {
  if (kind === 'device' && !token.startsWith('dt_')) throw denied();
  const [head, payload, sig, extra] = (kind === 'device' ? token.slice(3) : token).split('.');
  if (head !== header || !payload || !sig || extra !== undefined || !/^[\w-]{43}$/.test(sig)) throw denied();
  if (!timingSafeEqual(signature(kind, `${head}.${payload}`), Buffer.from(sig, 'base64url'))) throw denied();
  const claims = JSON.parse(Buffer.from(payload, 'base64url').toString()) as (Device | Access) & { exp: number };
  if (claims.exp <= Math.floor(Date.now() / 1000)) throw denied();
  return claims;
}
export function seal(value: unknown, scope: string) {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', derived('replay'), iv).setAAD(Buffer.from(scope));
  const encrypted = Buffer.concat([cipher.update(JSON.stringify(value)), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), encrypted]).toString('base64url');
}
export function unseal(value: string, scope: string): unknown {
  const b = Buffer.from(value, 'base64url');
  const cipher = createDecipheriv('aes-256-gcm', derived('replay'), b.subarray(0, 12))
    .setAAD(Buffer.from(scope)).setAuthTag(b.subarray(12, 28));
  return JSON.parse(Buffer.concat([cipher.update(b.subarray(28)), cipher.final()]).toString());
}
