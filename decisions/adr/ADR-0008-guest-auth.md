# ADR-0008: S1 backend draft

Use a device- and operation-scoped replay table because pre-auth requests have no account ID. Seal token responses with a derived AES-GCM key and atomic transaction; expiry cleanup on write is scope-local, and a global expiry job is required before rollout. The additive migration rolls back operationally by redeploying S0 and leaving the unused table in place.

Use fixed-algorithm Node crypto, injected auth policy defaults from `.env.example`, and a checked-in OpenAPI definition rather than new runtime dependencies. The replay table and independent device-pepper and auth secrets must be secured in any deployed environment. Do not merge the draft before the mobile and release work, global expiry, full OpenAPI schemas and staging QA.
