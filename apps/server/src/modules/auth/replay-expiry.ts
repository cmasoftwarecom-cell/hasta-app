import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class ReplayExpiry implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ReplayExpiry.name);
  private timer?: NodeJS.Timeout;
  private pending?: Promise<void>;

  constructor(private readonly db: PrismaClient) {}

  async onModuleInit() {
    this.schedule();
    await this.pending;
    this.timer = setInterval(() => this.schedule(), 60_000).unref();
  }

  async onModuleDestroy() {
    clearInterval(this.timer);
    await this.pending;
  }

  private schedule() {
    if (this.pending) return;
    this.pending = this.purge().then(async () => {
      // Keep terminal QR records no longer than the non-secret replay window.
      const cutoff = new Date(Date.now() - 604_800_000);
      await this.db.$executeRaw`DELETE FROM transfer_tokens WHERE id IN (
        SELECT id FROM transfer_tokens WHERE expires_at <= ${cutoff}
        ORDER BY expires_at LIMIT 500 FOR UPDATE SKIP LOCKED)`;
    }).catch(() => {
      this.logger.warn('Auth replay expiry sweep failed; will retry.');
    }).finally(() => { this.pending = undefined; });
  }

  async purge() {
    const now = new Date();
    let total = 0;
    for (;;) {
      // Limit each transaction; replicas skip rows another sweeper is deleting.
      const removed = await this.db.$executeRaw`
        DELETE FROM auth_requests AS expired
        USING (SELECT scope, key FROM auth_requests WHERE expires_at <= ${now}
          ORDER BY expires_at LIMIT 500 FOR UPDATE SKIP LOCKED) AS batch
        WHERE expired.scope = batch.scope AND expired.key = batch.key`;
      total += removed;
      if (removed < 500) return total;
    }
  }
}
