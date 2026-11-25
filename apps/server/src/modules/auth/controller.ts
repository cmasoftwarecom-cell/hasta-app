import { Body, CanActivate, Controller, Delete, ExecutionContext, Get, Header, Headers, HttpCode, Param, Post, Query, Res, UseGuards } from '@nestjs/common';
import { denied, failure, uuidPattern, verify } from './credentials';
import { GuestAuth } from './service';
const deviceToken = /^dt_[\w.-]{1,1024}$/;
const deviceProof = /^[\da-f]{64}$/;
const handles = /^(tester\.(a|b|social|premium|minor|fresh))$/;
const schemas = {
  register: { device_proof: deviceProof, raw_device_id: /^[\w:-]{1,128}$/, platform: /^(android|ios)$/, app_version: /^[\w.+-]{1,32}$/, os_version: /^[\w. +()-]{1,64}$/ },
  guest: { device_proof: deviceProof, device_token: deviceToken, locale: /^(my|en)$/ },
  refresh: { device_proof: deviceProof, device_token: deviceToken, refresh_token: /^rt_[\w-]{43}$/ },
  logout: { device_proof: deviceProof, device_token: deviceToken, everywhere: /^(true|false)$/ },
  qa: { device_proof: deviceProof, device_token: deviceToken, handle: handles, reset: /^(true|false)$/ },
};
type Action = keyof typeof schemas;
type Response = { setHeader(name: string, value: string): void };
export const bearer = (value?: string) => value?.match(/^Bearer ([\w.-]{1,1024})$/i)?.[1] ?? '';
export class AccessGuard implements CanActivate {
  canActivate(ctx: ExecutionContext) {
    verify('access', bearer(ctx.switchToHttp().getRequest().headers.authorization));
    return true;
  }
}
@Controller('v1')
export class AuthController {
  constructor(private readonly auth: GuestAuth) {}
  private async submit(action: Action, body: unknown, key: string, res: Response, authorization?: string) {
    if (action === 'qa' && !this.auth.qaAllowed) throw failure(404, 'not_found');
    const fields = Object.entries(schemas[action]);
    if (!body || typeof body !== 'object' || Array.isArray(body) || Object.keys(body).length !== fields.length || !uuidPattern.test(key ?? ''))
      throw failure(400, 'validation_failed');
    const input: Record<string, string> = {};
    for (const [name, pattern] of fields) {
      const value = (body as Record<string, unknown>)[name];
      if ((name === 'everywhere' || name === 'reset' ? typeof value !== 'boolean' : typeof value !== 'string') || !pattern.test(String(value)))
        throw failure(400, 'validation_failed');
      input[name] = String(value);
    }
    const { reply, replay } = await this.auth.write(action, input, key.toLowerCase(), bearer(authorization));
    if (reply === false) throw denied();
    if (replay) res.setHeader('Idempotent-Replayed', 'true');
    return reply;
  }
  @Post('auth/device/register') @HttpCode(200) @Header('Cache-Control', 'no-store')
  register(@Body() body: unknown, @Headers('idempotency-key') key: string, @Res({ passthrough: true }) res: Response) {
    return this.submit('register', body, key, res);
  }
  @Post('auth/guest') @HttpCode(200) @Header('Cache-Control', 'no-store')
  guest(@Body() body: unknown, @Headers('idempotency-key') key: string, @Res({ passthrough: true }) res: Response) {
    return this.submit('guest', body, key, res);
  }
  @Post('auth/refresh') @HttpCode(200) @Header('Cache-Control', 'no-store')
  refresh(@Body() body: unknown, @Headers('idempotency-key') key: string, @Res({ passthrough: true }) res: Response) {
    return this.submit('refresh', body, key, res);
  }
  @Post('auth/logout') @HttpCode(204) @UseGuards(AccessGuard) @Header('Cache-Control', 'no-store')
  logout(@Body() body: unknown, @Headers('idempotency-key') key: string, @Res({ passthrough: true }) res: Response,
    @Headers('authorization') authorization: string) {
    return this.submit('logout', body, key, res, authorization);
  }
  @Get('me') @UseGuards(AccessGuard) @Header('Cache-Control', 'no-store')
  me(@Headers('authorization') authorization: string) {
    return this.auth.me(bearer(authorization));
  }
  @Get('auth/sessions') @UseGuards(AccessGuard) @Header('Cache-Control', 'no-store')
  sessions(@Headers('authorization') authorization: string) {
    return this.auth.listSessions(bearer(authorization));
  }
  @Delete('auth/sessions') @HttpCode(204) @UseGuards(AccessGuard) @Header('Cache-Control', 'no-store')
  deleteOthers(@Query('others') others: unknown, @Headers('device-token') token: string,
    @Headers('device-proof') proof: string, @Headers('idempotency-key') key: string,
    @Headers('authorization') authorization: string, @Res({ passthrough: true }) res: Response) {
    if (others !== 'true') throw failure(400, 'validation_failed');
    return this.deleteSession('others', token, proof, key, authorization, res);
  }
  @Delete('auth/sessions/:id') @HttpCode(204) @UseGuards(AccessGuard) @Header('Cache-Control', 'no-store')
  deleteById(@Param('id') id: string, @Headers('device-token') token: string,
    @Headers('device-proof') proof: string, @Headers('idempotency-key') key: string,
    @Headers('authorization') authorization: string, @Res({ passthrough: true }) res: Response) {
    if (!uuidPattern.test(id)) throw failure(400, 'validation_failed');
    return this.deleteSession(id.toLowerCase(), token, proof, key, authorization, res);
  }
  private async deleteSession(target: string, device_token: string, device_proof: string, key: string,
    authorization: string, res: Response) {
    if (![device_token, device_proof, key].every((field) => typeof field === 'string') ||
        !deviceToken.test(device_token) || !deviceProof.test(device_proof) || !uuidPattern.test(key))
      throw failure(400, 'validation_failed');
    if (await this.auth.revokeSession(bearer(authorization), { device_token, device_proof }, target, key.toLowerCase()))
      res.setHeader('Idempotent-Replayed', 'true');
  }
  @Post('qa/guest') @HttpCode(200) @Header('Cache-Control', 'no-store')
  qa(@Body() body: unknown, @Headers('idempotency-key') key: string, @Res({ passthrough: true }) res: Response) {
    return this.submit('qa', body, key, res);
  }
}
