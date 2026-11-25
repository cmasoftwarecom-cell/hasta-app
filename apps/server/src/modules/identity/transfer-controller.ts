import { Body, Controller, Get, Header, Headers, HttpCode, Param, Post, Res } from '@nestjs/common';
import { failure, uuidPattern } from '../auth/credentials';
import { ConsentResponse, enrollmentFields, sendConsent, validated } from './consent-input';
import { DeviceTransfer } from './transfer-service';

const transferId = { transfer_id: new RegExp(`${uuidPattern.source}(?![\\s\\S])`, 'i') };
const bearer = (authorization: string | undefined) =>
  typeof authorization === 'string' && authorization.startsWith('Bearer ') ? authorization.slice(7) : '';

@Controller('v1/auth/transfer')
export class TransferController {
  constructor(private readonly transfers: DeviceTransfer) {}

  @Post('start') @HttpCode(200) @Header('Cache-Control', 'no-store')
  start(@Body() body: unknown, @Headers('idempotency-key') key: string, @Headers('authorization') token: string,
    @Res({ passthrough: true }) res: ConsentResponse) {
    const input = validated(body, key, { ...enrollmentFields, approval_key: /^[A-Za-z0-9_-]{122}$/ });
    return sendConsent(res, this.transfers.start(bearer(token), input, key.toLowerCase()));
  }

  @Post('redeem') @HttpCode(200) @Header('Cache-Control', 'no-store')
  redeem(@Body() body: unknown, @Headers('idempotency-key') key: string, @Res({ passthrough: true }) res: ConsentResponse) {
    const input = validated(body, key, { ...enrollmentFields, token: /^tt_[A-Za-z0-9_-]{43}$/ });
    return sendConsent(res, this.transfers.redeem(input, key.toLowerCase()));
  }

  @Post('confirm') @HttpCode(200) @Header('Cache-Control', 'no-store')
  confirm(@Body() body: unknown, @Headers('idempotency-key') key: string, @Headers('authorization') token: string,
    @Res({ passthrough: true }) res: ConsentResponse) {
    const { approval_signature, ...input } = validated(body, key, {
      ...enrollmentFields, ...transferId, approval_signature: /^[A-Za-z0-9_-]{11,96}$/,
    });
    return sendConsent(res, this.transfers.decide(bearer(token), input, key.toLowerCase(), approval_signature));
  }

  @Post('reject') @HttpCode(200) @Header('Cache-Control', 'no-store')
  reject(@Body() body: unknown, @Headers('idempotency-key') key: string, @Headers('authorization') token: string,
    @Res({ passthrough: true }) res: ConsentResponse) {
    const input = validated(body, key, { ...enrollmentFields, ...transferId });
    return sendConsent(res, this.transfers.decide(bearer(token), input, key.toLowerCase()));
  }

  @Post('claim') @HttpCode(200) @Header('Cache-Control', 'no-store')
  claim(@Body() body: unknown, @Headers('idempotency-key') key: string, @Res({ passthrough: true }) res: ConsentResponse) {
    const input = validated(body, key, { ...enrollmentFields, ...transferId });
    return sendConsent(res, this.transfers.claim(input, key.toLowerCase()));
  }

  @Get(':id') @Header('Cache-Control', 'no-store')
  status(@Param('id') id: string, @Headers('authorization') token: string) {
    if (!transferId.transfer_id.test(id)) throw failure(400, 'validation_failed');
    return this.transfers.inspect(bearer(token), id.toLowerCase());
  }
}
