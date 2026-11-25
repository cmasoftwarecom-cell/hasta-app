# ADR-0015: Single-use QR transfer and signed source approval

Status: Proposed in draft PR #2, disabled by default.

## Decision

- `start` returns a versioned QR with a server-derived 256-bit token. The row stores its SHA-256 digest. The server can regenerate the token for the same valid idempotency key, but its replay envelope stores only the transfer ID. There are at most two starts in three minutes per account and per source installation. Expiry is exactly 120 seconds from issuance, with no scan or approval extension.
- `redeem` requires a real, proved installation, with no bearer so a fresh device does not have to create a disposable guest. The first successful scan records the target and `used_at` without moving the account. A second scan under a different key or installation is rejected. Source status and the target receipt show a short matching code so the owner can compare the two devices.
- `confirm` accepts a P-256 signature over the scan-specific challenge, not a `biometric_verified` boolean. The source pins the public key for each transfer while proving its active bearer and installation. The official Android bridge requires API 30+, a hardware-backed Keystore key and per-operation strong biometric or device credential; the iOS bridge requests a Secure Enclave key with user presence. This is not remote attestation. The server trusts source enrollment to establish the key and cannot independently tell whether a modified source client used authenticated hardware.
- Confirm holds a target-device lock and the account lock in that order, rechecks vacancy, retires the old binding, creates/reactivates the target binding, and revokes every old-device session in a single transaction. Historical bindings are retained inactive, as in ADR-0013. Any other device's sessions are untouched. Moving an account does not use or clear account-creation cooldown.
- `claim` is a separate idempotent write on the exact new installation, not a QR bearer exchange. It issues the existing account's device-bound session only after confirmation and before expiry. Its encrypted replay receipt lasts at most 120 seconds and is valid only for a still-active session. If confirmation committed but the initial claim window elapsed, normal guest resume on the proved bound target can resume the transferred account without creating another account. Non-secret replay records and transfer metadata expire via the existing auth sweep.

## Rollout and differences from SPEC §5.5

Status uses source polling and target claim polling for local QA. Realtime `transfer.confirm_required` and `session.revoked` delivery are not implemented in this slice. The source Flutter repository clears local credentials on successful confirm and server access/refresh fails immediately after the transaction.

Flutter has the repository, signed approval bridge and QR payload parser; there is deliberately no user-visible scanner, renderer or navigation entry in this PR. Android exposes `FLAG_SECURE` to a future QR surface. iOS does not claim screenshot prevention; the presentation guard fails closed there until an approved capture-protection policy is implemented and tested. Keep `HASTA_AUTH_QR_TRANSFER_ENABLED=false` outside isolated QA. Do not wire an unprotected renderer, expose transfer on Welcome, or enable release traffic before on-device approval and T28 QA.

The generated migration is additive. Roll back application code or turn the flag off without dropping the columns. If schema removal is necessary, first disable the route and drain requests, then generate a reverse Prisma diff against the pre-QR schema and review it for loss of QR metadata only. Do not revert account bindings or valid sessions.
