# S1 staging QA checklist

Status: **not run**. The isolated CI API is not staging. Record the staging deployment revision, app build and device/OS, date in UTC, and test verdicts on PR #2 before marking this gate complete.

## Prerequisites

- Obtain the approved HTTPS staging API URL and confirm that it points to the PR revision, with the enrollment migration applied and a database and signing keys distinct from production.
- Use an approved synthetic install or dedicated staging device. Use a normal release-mode build for guest checks. If testing the QA picker, use a separate approved debug test/beta build and never enable the server flag on production.
- Do not put credentials, proof values, raw device identifiers, tokens, or test account details in evidence. Capture only build identifiers, step verdicts and redacted diagnostics.

## Smoke checks

| Gate | Action and expected result |
| --- | --- |
| T40 | Fresh install: one tap on Continue opens the guest profile. Confirm a guest account and active session using approved read-only staging telemetry. Reopen the app and verify the same profile appears. |
| T41 | Sign out, then tap Continue on the same install. The guest account is resumed without a duplicate; the signed-out session stays revoked. |
| T42 | With a pre-provisioned cooldown fixture, verify guest entry is rejected with `device_cooldown` and retry timing. Do not mutate a real user's account to create the fixture. |
| T36 | No fixture panel appears after a three-second hold in either platform's release app. On a separate enabled debug test/beta install, verify the picker works only with the approved fixture backend. |
| T46 | Confirm the automated isolated CI family-revocation check is green for the staged revision. Only repeat on staging with approved paired synthetic fixtures. |
| Offline | With a cached guest profile, disable networking, reopen, confirm that the profile remains readable with an offline notice, then reconnect and retry. |

Run on Android and iOS where signed staging builds are available. Record any failures or untested cases; a green CI artifact scan does not substitute for the staging results.
