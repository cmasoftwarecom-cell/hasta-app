# ADR-0011: Primary-button fills use the tracked design-token source

Status: proposed in draft PR #2.

The conformance review requested regeneration from `design/hastads1.0.2.json`, which is not in the repository. SPEC 1.0.1 and project state use DS 1.0.1. Keep its canonical `assets/design-tokens.json` and regenerate `tokens.dart` with the existing script rather than inventing a DS 1.0.2 file, editing generated Dart, or claiming a version bump.

Correct the disabled token to the SPEC §14.1 values, using explicit RGBA alpha for 40% light and 30% dark. The Welcome primary button resolves disabled, pressed, and default fills from the generated semantic tokens. Local widget tests exercise the rendered fills without a backend.
