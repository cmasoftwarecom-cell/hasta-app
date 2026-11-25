# ADR-0010: T47 OpenAPI bootstrap baseline before a release tag exists

Status: proposed in draft PR #2.

SPEC 1.0.1 T47 compares the API with the previous release tag. There is no release tag yet, and the merged S0 contract has no client operations. Skipping the diff or using the empty S0 contract would not detect a removal or breaking change to an S1 route.

Until a stable `v<major>.<minor>.<patch>` release exists on the trusted base history, compare against `docs/api/baselines/s1-bootstrap.json`, a byte-identical snapshot of `docs/api/openapi.json` at `fb0b3b0d1ea1f9b80ec59eb400ef207af8df19f6`. The selector checks its SHA-256 before use. The committed snapshot survives squash merges and does not advertise a release or require a synthetic tag. Do not regenerate it from the candidate contract.

For pull requests, choose the highest stable version tag reachable from the PR base SHA; for a push to `main`, use the pre-push SHA. This excludes tags present only on the candidate. If a selected release tag has no contract, fail rather than falling back. Missing base history or a changed bootstrap digest also fails the gate. Spectral still lints the candidate and oasdiff still fails on breaking errors.
