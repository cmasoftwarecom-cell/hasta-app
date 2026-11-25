import { failure, uuidPattern } from '../auth/credentials';

export type ConsentResponse = { setHeader(name: string, value: string): void };
export const enrollmentFields = { device_token: /^dt_[\w.-]{1,1024}$/, device_proof: /^[\da-f]{64}$/ };
export const completionFields = { ...enrollmentFields, state: /^[A-Za-z0-9_-]{43}$/, code: /^[\x21-\x7e]{1,2048}$/ };

export function validated<T extends Record<string, RegExp>>(body: unknown, key: string, expected: T): Record<keyof T, string> {
  if (!body || typeof body !== 'object' || Array.isArray(body) || typeof key !== 'string' || !uuidPattern.test(key) ||
      Object.keys(body).length !== Object.keys(expected).length) throw failure(400, 'validation_failed');
  for (const [name, test] of Object.entries(expected)) {
    const value = (body as Record<string, unknown>)[name];
    if (typeof value !== 'string' || !test.test(value)) throw failure(400, 'validation_failed');
  }
  return body as Record<keyof T, string>;
}

export async function sendConsent(res: ConsentResponse, outcome: Promise<{ replay: boolean; reply: unknown }>) {
  const { replay, reply } = await outcome;
  if (replay) res.setHeader('Idempotent-Replayed', 'true');
  return reply;
}
