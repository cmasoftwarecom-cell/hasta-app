import { Prisma } from '@prisma/client';
import { failure, seal, unseal } from '../auth/credentials';

export type ConsentTx = Prisma.TransactionClient;
export type EnrollmentInput = { device_token: string; device_proof: string };
export type ConsentInput = EnrollmentInput & { state: string; code: string };
export type ConsentSecret = { nonce: string; codeVerifier: string };
export const consentSeconds = 300;
export const consentLock = (tx: ConsentTx, scope: string) =>
  tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${scope}, 0))`;
export const loadConsent = (tx: ConsentTx, scope: string, key: string) =>
  tx.auth_requests.findFirst({ where: { scope, key, expires_at: { gt: new Date() } },
    select: { sealed: true, fingerprint: true } });
export const storeConsent = async (tx: ConsentTx, scope: string, key: string, fingerprint: string, value: unknown) => {
  await tx.auth_requests.deleteMany({ where: { scope, key, expires_at: { lte: new Date() } } });
  await tx.auth_requests.create({ data: { scope, key, fingerprint, sealed: seal(value, `${scope}:${key}:${fingerprint}`),
    expires_at: new Date(Date.now() + consentSeconds * 1000) } });
};
export const openConsent = <T>(row: { sealed: string; fingerprint: string }, scope: string, key: string, fingerprint: string): T => {
  if (row.fingerprint !== fingerprint) throw failure(409, 'idempotency_conflict');
  return unseal(row.sealed, `${scope}:${key}:${fingerprint}`) as T;
};
