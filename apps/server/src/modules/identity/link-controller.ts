import { Body, Controller, Delete, Header, Headers, HttpCode, Post, Res, UseGuards } from '@nestjs/common';
import { AccessGuard, bearer } from '../auth/controller';
import { failure, uuidPattern } from '../auth/credentials';
import { GoogleLinks } from './link-service';

type Reply = { setHeader(name: string, value: string): void };
const fields = { device_token: /^dt_[\w.-]{1,1024}$/, device_proof: /^[\da-f]{64}$/ };
const completeFields = { ...fields, state: /^[\w-]{43}$/, code: /^[\x21-\x7e]{1,2048}$/ };
function validated<T extends Record<string, RegExp>>(body: unknown, key: string, expected: T): Record<keyof T, string> {
  if (!body || typeof body !== 'object' || Array.isArray(body) || !uuidPattern.test(key ?? '') ||
      Object.keys(body).length !== Object.keys(expected).length) throw failure(400, 'validation_failed');
  for (const [name, test] of Object.entries(expected)) {
    const value = (body as Record<string, unknown>)[name];
    if (typeof value !== 'string' || !test.test(value)) throw failure(400, 'validation_failed');
  }
  return body as Record<keyof T, string>;
}

@Controller('v1/auth/identities/google')
@UseGuards(AccessGuard)
export class GoogleLinkController {
  constructor(private readonly links: GoogleLinks) {}

  // Escape Express's named-parameter syntax; the colon is literal on the wire.
  @Post('link\\:start') @HttpCode(200) @Header('Cache-Control', 'no-store')
  start(@Body() body: unknown, @Headers('idempotency-key') key: string,
    @Headers('authorization') auth: string, @Res({ passthrough: true }) res: Reply) {
    return this.send(res, this.links.start(bearer(auth), validated(body, key, fields), key.toLowerCase()));
  }

  @Post('link\\:complete') @HttpCode(200) @Header('Cache-Control', 'no-store')
  complete(@Body() body: unknown, @Headers('idempotency-key') key: string,
    @Headers('authorization') auth: string, @Res({ passthrough: true }) res: Reply) {
    return this.send(res, this.links.complete(bearer(auth), validated(body, key, completeFields), key.toLowerCase()));
  }

  @Delete() @HttpCode(204) @Header('Cache-Control', 'no-store')
  unlink(@Headers('device-token') device_token: string, @Headers('device-proof') device_proof: string,
    @Headers('idempotency-key') key: string,
    @Headers('authorization') auth: string, @Res({ passthrough: true }) res: Reply) {
    return this.send(res, this.links.unlink(bearer(auth), validated({ device_token, device_proof }, key, fields), key.toLowerCase()));
  }

  private async send(res: Reply, outcome: Promise<{ replay: boolean; reply: unknown }>) {
    const { replay, reply } = await outcome;
    if (replay) res.setHeader('Idempotent-Replayed', 'true');
    return reply;
  }
}
