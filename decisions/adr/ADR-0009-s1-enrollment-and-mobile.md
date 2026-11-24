# ADR-0009: S1 installation proof, replay lifecycle, and mobile QA

Status: proposed in draft PR #2. Extends ADR-0008 without changing the guest-only entry policy.

## Enrollment and rollout

An OS identifier is not a credential. Require a CSPRNG-generated 32-byte installation proof on enrollment and all four S1 auth writes plus the private QA write, with constant-time digest comparison before replay. Persist only its SHA-256 digest as a server-side enrollment row; bind it to the peppered device identifier and platform. Device possession here means possession of the stored installation secret, not OS attestation. The scheme does not protect the first enrollment against pre-claiming an identifier or a compromised installation that loses the proof.

Deploy the additive Prisma migration first; deploy the updated server and client together. There is no production S1 baseline with existing enrollments. Existing unenrolled bindings fail closed: do not script a raw-ID claim or backfill an unknown proof. If disposable staging has pre-change fixtures, reset only the isolated fixture data and re-enroll from an empty test install. Loss of the installation proof behaves like loss of the device for a guest; identity recovery is S2. Android retains a stable OS identifier across some reinstalls and the app cannot safely reclaim the account from that identifier. For a non-production DB, legacy binaries can be rolled back without reverting the additive table, but the old binaries must not serve S1 accounts because they bypass enrollment proof.

## Replay

Auth replay records remain sealed and scoped by operation/device (and account for logout). Saved session responses are refused if their access token or underlying session/binding/account is no longer valid. A global batched sweep at startup and every minute removes expired rows even for idle devices; replicas use `SKIP LOCKED`, and lookup enforces expiry even during job outages. Monitor sweep failures and age of the oldest expired row. Live DB expiry does not bound backup retention; deployment must confirm its encrypted backup and deletion policy separately.

## Mobile

Use the specified Flutter/Dio/Drift stack. Approve pinned mobile support packages `crypto`, `flutter_secure_storage`, `path_provider`, and `sqlite3_flutter_libs`, and pinned build-time generators `build_runner` / `drift_dev`. Android uses EncryptedSharedPreferences with a Keystore-backed key (minimum API 23); iOS uses an unlocked, this-device-only Keychain item. Keep the proof, tokens and pending auth idempotency keys out of Drift; Drift stores only account ID, display name and username for a local read-only profile offline. Online auth writes are not a general-purpose offline outbox.

Only the welcome entry is primary. Privacy & Terms is an explicitly labeled preview until approved legal content is available. The QA picker is compile-time disabled in release even if explicitly enabled by build defines. In S1 its six handles are isolated guest profiles, with a minor birth date seeded; dating verification, page ownership, and Premium fixtures wait for their owning sprints. Keep beta/test infrastructure isolated from production. Android’s artifact gate tests the hostile combination of QA defines enabled in release; iOS native verification and staging/device QA are separate.
