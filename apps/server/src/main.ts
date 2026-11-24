import 'reflect-metadata';
import { Controller, Get, Header, Injectable, Module, OnModuleDestroy } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';

@Injectable()
export class Database extends PrismaClient implements OnModuleDestroy {
  async onModuleDestroy(): Promise<void> {
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

@Module({ controllers: [HealthController], providers: [Database] })
class AppModule {}

export async function createApp() {
  const app = await NestFactory.create(AppModule, { bodyParser: false, logger: false });
  app.use((_request: unknown, response: { setHeader(name: string, value: string): void },
    next: () => void) => {
    response.setHeader('X-Request-Id', randomUUID());
    next();
  });
  app.enableShutdownHooks();
  return app;
}

if (require.main === module) {
  void createApp().then((app) => app.listen(3000, '0.0.0.0')).catch(() => {
    process.stderr.write('Hasta server failed to start.\n');
    process.exitCode = 1;
  });
}
