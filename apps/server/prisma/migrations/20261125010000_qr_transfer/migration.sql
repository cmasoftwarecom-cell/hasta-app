-- AlterTable
ALTER TABLE "transfer_tokens" ADD COLUMN     "approval_key" TEXT,
ADD COLUMN     "claimed_at" TIMESTAMPTZ(6),
ADD COLUMN     "source_bound_at" TIMESTAMPTZ(6),
ADD COLUMN     "target_bound_at" TIMESTAMPTZ(6);

-- CreateIndex
CREATE INDEX "transfer_tokens_account_id_created_at_idx" ON "transfer_tokens"("account_id", "created_at");

-- CreateIndex
CREATE INDEX "transfer_tokens_from_device_created_at_idx" ON "transfer_tokens"("from_device", "created_at");

-- CreateIndex
CREATE INDEX "transfer_tokens_expires_at_idx" ON "transfer_tokens"("expires_at");
