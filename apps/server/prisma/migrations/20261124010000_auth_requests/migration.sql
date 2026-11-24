-- CreateTable
CREATE TABLE "auth_requests" (
    "scope" TEXT NOT NULL,
    "key" UUID NOT NULL,
    "fingerprint" TEXT NOT NULL,
    "sealed" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "auth_requests_pkey" PRIMARY KEY ("scope","key")
);

-- CreateIndex
CREATE INDEX "auth_requests_expires_at_idx" ON "auth_requests"("expires_at");
