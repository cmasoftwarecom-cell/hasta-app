import { Body, Controller, Delete, Get, Header, Headers, HttpCode, Post, Res, UseGuards } from '@nestjs/common';
import { AccessGuard, bearer } from '../auth/controller';
import { GoogleLinks } from './link-service';
import { ConsentResponse as Reply, completionFields as completeFields,
  enrollmentFields as fields, sendConsent, validated } from './consent-input';

@Controller('v1/auth/identities/google')
@UseGuards(AccessGuard)
export class GoogleLinkController {
  constructor(private readonly links: GoogleLinks) {}

  @Get() @Header('Cache-Control', 'no-store')
  status(@Headers('authorization') auth: string) {
    return this.links.status(bearer(auth));
  }

  // Escape Express's named-parameter syntax; the colon is literal on the wire.
  @Post('link\\:start') @HttpCode(200) @Header('Cache-Control', 'no-store')
  start(@Body() body: unknown, @Headers('idempotency-key') key: string,
    @Headers('authorization') auth: string, @Res({ passthrough: true }) res: Reply) {
    return sendConsent(res, this.links.start(bearer(auth), validated(body, key, fields), key.toLowerCase()));
  }

  @Post('link\\:complete') @HttpCode(200) @Header('Cache-Control', 'no-store')
  complete(@Body() body: unknown, @Headers('idempotency-key') key: string,
    @Headers('authorization') auth: string, @Res({ passthrough: true }) res: Reply) {
    return sendConsent(res, this.links.complete(bearer(auth), validated(body, key, completeFields), key.toLowerCase()));
  }

  @Delete() @HttpCode(204) @Header('Cache-Control', 'no-store')
  unlink(@Headers('device-token') device_token: string, @Headers('device-proof') device_proof: string,
    @Headers('idempotency-key') key: string,
    @Headers('authorization') auth: string, @Res({ passthrough: true }) res: Reply) {
    return sendConsent(res, this.links.unlink(bearer(auth), validated({ device_token, device_proof }, key, fields), key.toLowerCase()));
  }
}
