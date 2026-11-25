# Hasta — Myanmar Copy Review Brief (copywriter pack)

**Purpose:** 47 Myanmar strings + Privacy/Terms copy are pending native approval (`docs/i18n/copy-review.md` in the `hasta-app` repo). This is an App Store / Google Play submission blocker, so it must run **in parallel** with Sprint 2, not after it.

**How to use this file:** send this file plus the repo's `docs/i18n/copy-review.md` (or the exported `lib/l10n/app_my.arb`) to the copywriter. This brief is self-contained — the copywriter does not need repo access.

---

## 1. What we are asking for

For each string: approve, or rewrite so it sounds like natural Myanmar app copy (not translated English). Flag anything ambiguous, and give the final approved Myanmar text.

Return format — one row per key:

| key | current Myanmar | approved? (yes / rewrite) | final Myanmar | note (tone, length, ambiguity) |
| --- | --- | --- | --- | --- |

Also answer three yes/no questions at the end:
1. Do any strings read as condescending or age-specific (ဤ ခင်ဗျား/ညီကို/အစ်ကို tone)?
2. Do any strings exceed the width limit we marked (bottom-nav label ≤ 6 words, buttons = verb only)?
3. Any string where the English and Myanmar mean different things?

## 2. Voice (binding)

**Plain, respectful, encouraging. Formal-lite. Age-neutral** — no ခင်ဗျား / ညီကို / အစ်ကို. Light English loanwords are acceptable for tech terms Myanmar users already know, but the glossary terms below are closed — they must not be replaced by transliterations.

## 3. Glossary — mandatory, do not substitute

| Concept | Must use | Must NOT use |
| --- | --- | --- |
| Post | ပို့စ် | အပ်တင် |
| Comment | မှတ်ချက် | ကွန့်မန့် |
| Share | မျှဝေ | ရှဲ |
| Follow | လိုက်ကြည့် | ဖော်လိုး |
| Friend request | သူငယ်ချင်း တောင်းဆို | ဖရန့်ရီကွက် |
| Match | တွဲဖက် | မက်ချ် |
| Nearby | အနီးအနား | နီးဘိုင်း |
| Offline transfer | အင်တာနက်မလိုဘဲ ပို့ | — |

## 4. Structural rules the copy must obey

- **Error formula:** `[what happened] + [what to do] + [(hidden) error code]` — the user-facing part never shows a bare code like "Error 500".
- **Destructive buttons:** verb only ("ဖျက်သည်", "ပိတ်သည်") — never "OK", never "Yes/No".
- **Bottom-nav labels:** ≤ 6 words, and they disappear at large text sizes so they must read standalone.
- **Never uppercase-styled headings** — Myanmar has no uppercase, an overline label must not be capitalised.
- **Numbers/time:** 24-hour default (၁၉:၄၅), Arabic numerals by default (၁,၂၄၅ as an option), relative time as "၅ မိနစ်က / မနေ့က / ၁၂ ရက် / ၁ နှစ်က", distance banded as "၁ ကီလိုမီတာအတွင်း" / "~၃ ကီလိုမီတာ" — **never** an exact metre figure.
- **Char limits:** dating bio ≤ 300 chars; error copy should stay under ~90 Myanmar chars where a toast shows it.

## 5. Normative strings already approved by the spec (keep, or improve without changing meaning)

| Context | Approved copy |
| --- | --- |
| Welcome CTA | `စတင်အသုံးပြုရန်` |
| Guest explainer | `အီးမေးလ်၊ ဖုန်းနံပါတ် မလိုပါ။ ဤဖုန်းဖြင့် ချက်ချင်း စတင်နိုင်သည်။` |
| Guest risk notice | `ဖုန်းပျောက်ပါက ဤအကောင့်ကို ပြန်ရနိုင်မည် မဟုတ်ပါ။ Gmail ချိတ်ဆက်ထားရန် အကြံပြုသည်။` |
| Connect Gmail | `Gmail ချိတ်ဆက်ရန်` / linked: `ချိတ်ဆက်ပြီး — h***@gmail.com` |
| Gmail benefit sheet | `ချိတ်ဆက်ပါက — (၁) ဖုန်းပြောင်းလျှင် အကောင့် ပြန်ရနိုင်သည် (၂) Premium ဝယ်ယူနိုင်သည် (၃) Restore Purchases သုံးနိုင်သည်။` |
| Purchase blocked (guest) | `Premium ဝယ်ယူရန် Gmail ချိတ်ဆက်ထားရပါမည်။` |
| Offline banner | `အင်တာနက်မရှိပါ။ ပို့ထားသော စာများကို ချိတ်ဆက်သည့်အချိန် ပို့ပေးပါမည်။` |
| Opener limit | `ဤချတ်ဖြင့် နောက်ထပ် မက်ဆေ့ချ် ၁ ခုသာ ပို့နိုင်သေးသည်။ ဖြေကြားမှု ရရှိပါက ကန့်သတ်ချက် ပြေလျော့မည်။` |
| Under 18 | `Dating ကို အသက် ၁၈ နှစ်ပြည့်ပြီးမှ အသုံးပြုနိုင်ပါသည်။` |
| Unmatch confirm | title `ဒီတွဲဖက်ကို ဖျက်မလား?` · body `နှစ်ဖက်စလုံးအတွက် ချက်ချင်း ပိတ်သွားမည်။ လုံခြုံရေးအတွက် သက်သေ ၃၀ ရက် ထိန်းထားပါမည်။` · action `ဖျက်သည်` |
| Generic error | `မအောင်မြင်ပါ။ ခဏနောက် ပြန့်ကြိုးစားပါ။` |
| Upload too large | `ဖိုင် ကြီးလွန်းပါသည် (အများဆုံး ၂၀ MB)။ ဖိုင် သေးငယ်အောင် လုပ်ပါ။` |
| Safety banner | money/link/personal-data request warning — must warn without accusing the other user |

## 6. Special items that need a human, not a translation

1. **Privacy policy + Terms of Service** — currently placeholders. Copywriter drafts the *user-facing plain-Myanmar* version; **legal review is still mandatory** and must sign off before submission. Keep the retention facts exactly as written (they are `[PROPOSAL]` values pending legal): account data purged 30 days after deletion request, report evidence kept 30 days after a report closes, device-hash abuse log 90 days, database backups expire within 35 days. Do not soften or strengthen these numbers.
2. **Dating safety copy** — unmatch, dormant chat, media blur reveal, report confirmation. Tone: calm, no blame, no fear-mongering, no legal threat.
3. **Push notifications** — must be privacy-safe (no name, no photo, no message content in lock-screen text). Approve the generic wording only.
4. **Store listing text** (App Store / Google Play short + long description) — must not promise dating success, must state the 18+ gate and the report/block/moderation capability.
5. **QA panel strings** are English-only by design (dev/test builds only) — no translation needed, confirm they are never user-visible in release.

## 7. Turnaround & integration

Return the table; we merge it as `lib/l10n/app_my.arb` values plus a `docs/i18n/approved-by.md` note recording the reviewer and date. Any string still unapproved at release cut is a **release blocker**, not a "nice to have" — flagged P1 in the Sprint 1 review.

## 8. What we are NOT asking

No marketing copy, no ASO keyword work, no legal opinion, no change to product rules or numbers. If a rule itself seems wrong (e.g. the 3-message opener limit reads harshly), say so in the note column — we decide it from a user test, not in translation.
