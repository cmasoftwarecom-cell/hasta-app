import 'reflect-metadata';
import { ArgumentsHost, Catch, Controller, Get, Header, HttpException, Injectable, Module, OnApplicationShutdown } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { PrismaClient } from '@prisma/client';
import { AuthController } from './modules/auth/controller';
import { GuestAuth } from './modules/auth/service';
import { ReplayExpiry } from './modules/auth/replay-expiry';
import { uuid7, uuidPattern } from './modules/auth/credentials';
import { GoogleLinkController } from './modules/identity/link-controller';
import { GOOGLE_LINK, GoogleLinks, googleLinkProvider } from './modules/identity/link-service';

@Injectable()
export class Database extends PrismaClient implements OnApplicationShutdown {
  async onApplicationShutdown(): Promise<void> {
    await this.$disconnect();
  }
}

// Internal orchestration probe, not part of the /v1 client API.
@Controller()
class HealthController {
  @Get('health')
  @Header('Cache-Control', 'no-store')
  health() {
    return { status: 'ok' };
  }
}

@Catch()
class ApiErrors {
  catch(error: unknown, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse();
    const status = error instanceof HttpException ? error.getStatus() : 500;
    const cause = error instanceof HttpException ? error.getResponse() : null;
    const body = cause as { code?: string; seconds?: number; details?: object } | null;
    const code = body?.code ?? (status < 500 ? 'validation_failed' : 'internal_error');
    if (body?.seconds) res.setHeader('Retry-After', String(body.seconds));
    res.status(status).set('Cache-Control', 'no-store').json({ error: { code, message_key: `error.${code}`,
      status, request_id: res.getHeader('X-Request-Id'), details: body?.details ?? {}, retry_after_seconds: body?.seconds ?? null } });
  }
}
@Module({ controllers: [HealthController, AuthController, GoogleLinkController],
  providers: [Database, { provide: PrismaClient, useExisting: Database }, GuestAuth, ReplayExpiry,
    GoogleLinks] })
class AppModule {}

export async function createApp(providerFactory = googleLinkProvider) {
  const app = await NestFactory.create({
    module: AppModule, providers: [{ provide: GOOGLE_LINK, useFactory: providerFactory }],
  }, { logger: ['warn', 'error'] });
  app.use((request: { headers: Record<string, unknown> }, response: { setHeader(name: string, value: string): void },
    next: () => void) => {
    const id = request.headers['x-request-id'];
    response.setHeader('X-Request-Id', typeof id === 'string' && uuidPattern.test(id) ? id : uuid7());
    next();
  });
  app.useGlobalFilters(new ApiErrors());
  app.enableShutdownHooks();
  return app;
}

if (require.main === module) {
  void createApp().then((app) => app.listen(3000, '0.0.0.0')).catch(() => {
    process.stderr.write('Hasta server failed to start.\n');
    process.exitCode = 1;
  });
}
