-- CreateTable
CREATE TABLE "device_enrollments" (
    "device_hash" TEXT NOT NULL,
    "proof_hash" TEXT NOT NULL,
    "platform" "device_platform" NOT NULL,
    "qa_only" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "device_enrollments_pkey" PRIMARY KEY ("device_hash")
);
