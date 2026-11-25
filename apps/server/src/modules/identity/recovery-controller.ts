import { Body, Controller, Header, Headers, HttpCode, Post, Res } from '@nestjs/common';
import { ConsentResponse, completionFields, enrollmentFields, sendConsent, validated } from './consent-input';
import { GmailRecovery } from './recovery-service';

@Controller('v1/auth')
export class RecoveryController {
  constructor(private readonly recovery: GmailRecovery) {}

  @Post('recover\\:start') @HttpCode(200) @Header('Cache-Control', 'no-store')
  start(@Body() body: unknown, @Headers('idempotency-key') key: string, @Res({ passthrough: true }) res: ConsentResponse) {
    const input = validated(body, key, { ...enrollmentFields, provider: /^google$/ });
    return sendConsent(res, this.recovery.start(input, key.toLowerCase()));
  }

  @Post('recover\\:complete') @HttpCode(200) @Header('Cache-Control', 'no-store')
  complete(@Body() body: unknown, @Headers('idempotency-key') key: string, @Res({ passthrough: true }) res: ConsentResponse) {
    return sendConsent(res, this.recovery.complete(validated(body, key, completionFields), key.toLowerCase()));
  }
}
