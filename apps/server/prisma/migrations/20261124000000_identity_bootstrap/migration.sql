-- CreateEnum
CREATE TYPE "account_status" AS ENUM ('active', 'paused', 'deleted', 'banned');

-- CreateEnum
CREATE TYPE "identity_provider" AS ENUM ('guest', 'google', 'apple');

-- CreateEnum
CREATE TYPE "binding_role" AS ENUM ('primary', 'secondary');

-- CreateEnum
CREATE TYPE "device_platform" AS ENUM ('android', 'ios');

-- CreateEnum
CREATE TYPE "transfer_status" AS ENUM ('pending', 'confirmed', 'expired', 'rejected');

-- CreateEnum
CREATE TYPE "abuse_event" AS ENUM ('guest_created', 'account_deleted');

-- CreateTable
CREATE TABLE "accounts" (
    "id" UUID NOT NULL,
    "status" "account_status" NOT NULL DEFAULT 'active',
    "is_guest" BOOLEAN NOT NULL DEFAULT true,
    "display_name" TEXT,
    "username" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ(6),
    "purge_at" TIMESTAMPTZ(6),
    "updated_hlc" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "identities" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "provider" "identity_provider" NOT NULL,
    "provider_sub" TEXT NOT NULL,
    "email" TEXT,
    "email_verified" BOOLEAN NOT NULL DEFAULT false,
    "linked_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "identities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "device_bindings" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "device_hash" TEXT NOT NULL,
    "role" "binding_role" NOT NULL DEFAULT 'primary',
    "platform" "device_platform" NOT NULL,
    "push_token" TEXT,
    "bound_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revoked_at" TIMESTAMPTZ(6),

    CONSTRAINT "device_bindings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sessions" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "device_hash" TEXT NOT NULL,
    "refresh_hash" TEXT NOT NULL,
    "family_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "revoked_at" TIMESTAMPTZ(6),
    "revoked_reason" TEXT,
    "last_seen_at" TIMESTAMPTZ(6),

    CONSTRAINT "sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "transfer_tokens" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "token_hash" TEXT NOT NULL,
    "from_device" TEXT NOT NULL,
    "to_device" TEXT,
    "status" "transfer_status" NOT NULL DEFAULT 'pending',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "used_at" TIMESTAMPTZ(6),

    CONSTRAINT "transfer_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "device_cooldowns" (
    "device_hash" TEXT NOT NULL,
    "reason" TEXT NOT NULL DEFAULT 'account_deleted',
    "until" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "device_cooldowns_pkey" PRIMARY KEY ("device_hash")
);

-- CreateTable
CREATE TABLE "abuse_logs" (
    "id" BIGSERIAL NOT NULL,
    "device_hash" TEXT NOT NULL,
    "event" "abuse_event" NOT NULL,
    "occurred_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "abuse_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "profiles" (
    "user_id" UUID NOT NULL,
    "display_name" TEXT NOT NULL,
    "bio" TEXT,
    "avatar_key" TEXT,
    "birth_date" DATE,
    "privacy" JSONB NOT NULL DEFAULT '{}',
    "updated_hlc" BIGINT NOT NULL DEFAULT 0,
    "field_hlc" JSONB NOT NULL DEFAULT '{}',

    CONSTRAINT "profiles_pkey" PRIMARY KEY ("user_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "accounts_username_key" ON "accounts"("username");

-- CreateIndex
CREATE UNIQUE INDEX "identities_provider_provider_sub_key" ON "identities"("provider", "provider_sub");

-- CreateIndex
CREATE INDEX "idx_device_bindings_hash" ON "device_bindings"("device_hash", "revoked_at");

-- CreateIndex
CREATE UNIQUE INDEX "device_bindings_account_id_device_hash_key" ON "device_bindings"("account_id", "device_hash");

-- CreateIndex
CREATE UNIQUE INDEX "sessions_refresh_hash_key" ON "sessions"("refresh_hash");

-- CreateIndex
CREATE INDEX "sessions_family_id_idx" ON "sessions"("family_id");

-- CreateIndex
CREATE UNIQUE INDEX "transfer_tokens_token_hash_key" ON "transfer_tokens"("token_hash");

-- CreateIndex
CREATE INDEX "idx_abuse_device_window" ON "abuse_logs"("device_hash", "occurred_at");

-- AddForeignKey
ALTER TABLE "identities" ADD CONSTRAINT "identities_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "accounts"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "device_bindings" ADD CONSTRAINT "device_bindings_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "accounts"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "accounts"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "transfer_tokens" ADD CONSTRAINT "transfer_tokens_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "accounts"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "profiles" ADD CONSTRAINT "profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "accounts"("id") ON DELETE CASCADE ON UPDATE NO ACTION;
