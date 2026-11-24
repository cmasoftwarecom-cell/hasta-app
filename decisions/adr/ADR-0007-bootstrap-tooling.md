# ADR-0007: Bootstrap schema and build tooling

Status: proposed in S0.

Prisma 5 generates the baseline SQL. Use native PostgreSQL enums for the
checked literals in SPEC §13, application-supplied UUIDv7 identifiers (no
random UUIDv4 defaults), a composite binding lookup index because Prisma 5
cannot express predicates, and `BIGSERIAL` for Prisma's `BigInt autoincrement`.
These preserve field values and uniqueness at the DB boundary; the binding
query includes `revoked_at IS NULL`. No application data existed on this
branch before this additive migration. Roll back a failed sandbox bootstrap by
discarding the new sandbox database, not by dropping tables on a shared DB.

The toolchain includes TypeScript/Node types, Nest runtime peers
(`reflect-metadata`, RxJS, Express adapter), the Flutter SDK's localization
tooling, Spectral and oasdiff. Use Nest 11 (above the Nest 10 minimum in
SPEC §4) for upstream advisory fixes with the same Node 20 runtime;
override transitive `qs` to its patched version. The S0 process does not
enable request-body parsing or accept uploads. S0 uses
Node's built-in test runner for the small framework smoke; business tests
remain planned for the spec's Jest suite. Terraform declares the AWS provider
and remote-state boundary but provisions no resources in S0.
