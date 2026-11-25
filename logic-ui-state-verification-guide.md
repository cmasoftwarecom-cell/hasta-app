# Logic နှင့် UI State များ တိကျစွာ စစ်ဆေးခြင်း Guide (Hasta SPEC 1.0.1 / PR #2)

> ရည်ရွယ်ချက်: "စမ်းသပ်ပြီး" ဟု ပြောမပြုဘဲ၊ Logic တစ်ခုစီနှင့် UI State တစ်ခုစီကို
> **RED → GREEN** ပြောင်းလဲမှုဖြင့် အတည်ပြုနိုင်သော တိကျသည့် checklist။
> အောက်ပါ assertion များသည် PR #2 review မှ P0/P1 findings နှင့် SPEC test IDs (T37/T40/T41/T46/T47/T48) ပေါ်တွင် တည်ဆောက်ထားသည်။
> စံသတ်မှတ်ချက်: **Test ကို အရင်ရေး (RED) → ပြင် (GREEN) → committed test ဖြင့်မှသာ အတည်ပြုပြီးဟု သတ်မှတ်။ Scratch/manual pass မလုံ့ာ။**

---

## အပိုင်း ၁ — Logic State စစ်ဆေးခြင်း (Server / Auth)

စစ်ဆေးရာတွင် **isolated DB + synthetic fixtures** သုံးပါ။ Shared/production DB တွင် မစမ်းပါနှင့်။
တစ်ခုစီအတွက် "RED အဖြစ် ဘာကို ပြင်ရင် ပြန်ကျမလဲ" column သည် regression guard ဖြစ်သည်။

| ID | State / Logic | တိကျသော Assertion (တစ်ခုချင်း) | RED ဖြစ်စေမည့် ပြောင်းပြန်စမ်းသပ်မှု |
| --- | --- | --- | --- |
| T46a | Cross-device refresh | Token A ကို Device-1 ဖြင့် enroll၊ active (မလှည့်သေးသော) refresh token ကို Device-2 binding ဖြင့် တင် → **401 + token family revoked** ဖြစ်ရမည် | mismatch check ကို scratch တွင် ဖျက်လျှင် **200** ပြန်ရရမည် (မရလျှင် test သည် guard မစမ်းထား) |
| T46b | Active-token committed regression | Committed test သည် **already-rotated token** မဟုတ်ဘဲ **active token** ဖြင့် cross-device case ကို များထားရမည် | committed file တွင် active-token case မပါလျှင် committed test မှ guard ကို မဖမ်းနိုင် |
| P0-DEVICE-PROOF | Guest resume / device ownership | Registration တွင် caller-supplied identifier ကို hash လုပ်သော်လည်း **enrollment အတွင်း proof** မပါလျှင် resume ကို **ငြင်း** ရမည် | resume ကို hash တူခြင်းဖြင့်သာ ယုံလျှင် ownership မစမ်းဘူး (fail-closed မဟုတ်) |
| P0-REPLAY-RETENTION | Expired replay row | Expired replay row ကို **တခြား device request မလိုဘဲ global expiry** ဖြင့် ဖျက်ရမည် | cleanup ကို same-scope အခြား request ဖြင့်သာ လုပ်လျှင် inactive device token ကို အပြီးတိုင် ထားရှိနေ |
| P1-REPLAY-STATE | Idempotent retry vs revoked session | Session valid သာ idempotent retry သည် success + တူညီသော token ပြန်ရမည် | logout/family revocation ပြီးနောက် same-key retry သည် **success မပြန်ရ**ရ၊ cached response ကို session state မစမ်းဘဲ မပြန်ရ |
| Guest enroll | New device | မသိသော device ကို enroll → session + device-bound credential ဖြစ်ပေါ်၊ token family id မတူ | တူသော hash ကို အစဉ်သုံးလျှင် distinct-device မခွဲနိုင် |
| Logout | Family revocation | Logout ပြီးနောက် မိသားစု refresh token အားလုံး **401** | access session မပိတ်လျှင် revoke မပြည့်စုံ |
| T47 | OpenAPI breaking-change gate | Spectral lint + **oasdiff vs previous tag** နှစ်ခုလုံး run ဖြစ်နေရမည် | release tag မရှိလျှင် baseline-skip ဖြစ်နေ (first-release tag ဖန်တီးမှသာ တကယ့် diff run ဖြစ်) |
| T48 | Postgres pin | `docker-compose.yml` image == `postgres:16` တိကျ | `postgres:18` ပြောင်းလျှင် gate **RED** ဖြစ်ရမည် |

**Logic verify အဆင့် (တစ်ခုစီအတွက် လိုက်နာရမည့်ပုံစံ)**
1. Test ကို အရင်ရေး → run → **RED** (fail) တွေ့ရမည်။
2. Code ပြင် → run → **GREEN**။
3. Scratch copy တွင် guard ကို **တမင်ဖျက်** ပြီး RED ပြန်ဖြစ်ကြောင်း အတည်ပြု (test သည် guard ကို တကယ်စမ်းနေကြောင်း သက်သေ)။
4. Committed file တွင် ထို case ပါကြောင်း git diff ဖြင့် စစ်။
5. Isolated DB ဖြင့်သာ run ကြောင်း log တွင် ထား။

---

## အပိုင်း ၂ — UI State စစ်ဆေးခြင်း (Flutter)

Device matrix: **320×568 (Smallest) + 200% text scale**၊ locale **English + Myanmar နှစ်ခုလုံး**။
State တိုင်းကို widget test နှင့် screenshot golden ဖြင့် စစ်။ အောက်က state များကို **မလွှတ်ရ**။

### ၂.၁ Screen-by-screen state matrix

| Screen | ဖြစ်ရမည့် State များ | Assertion |
| --- | --- | --- |
| Welcome | idle / loading / error | အင်္ဂလိပ် + မြန်မာ 200% တွင် truncation မဖြစ်၊ button fill token မှန် |
| Guest Profile | loading / loaded / error | text မည်သည့်အခါမျှ truncate မဖြစ်ရ (minHeight + Expanded + lineHeight >= 1.65) |
| Settings | idle / loading / error | title truncate မဖြစ်ရ (FittedBox scaleDown) |
| Linked Accounts | **empty / loading / error / permission-denied / linked** | ငါးခုလုံး render + screenshot၊ ဤ branch တွင် မရှိသေး → S1 scope ဆုံးဖြတ်ရမည် |
| Connect Gmail (offline) | disabled-button state | T43: server/launcher call **သုည**၊ assertion တွင် disable ဖြစ်ကြောင်း + call မခေါ်ကြောင်း |

### ၂.၂ Text Scale / Truncation (T40/T41)

- [ ] Guest Profile: `minHeight` သတ် + text ကို `Expanded` ထဲ → 200%/320×568 EN+MM truncate မဖြစ်။
- [ ] Settings title: `FittedBox(fit: BoxFit.scaleDown)` → ellipsis မဟုတ်ဘဲ shrink-to-fit။
- [ ] Myanmar line height >= **1.65×** (`lineHeight >= 1.65`)။
- [ ] Global text scale ကို 1.0 ဟု လိမ်ပြင်မထားရ — accessibility fail ဖြစ်မည်။
- [ ] Overflow control (fixed-height) ကို **တမင်ထည့်**၍ intentional overflow control ကို **fail** စစ် — test က truncation ကို တကယ်ဖမ်းနိုင်ကြောင်း သက်သေ။

### ၂.၃ Design Tokens (Primary button)

- [ ] `bg.brand` (normal) သာမက **`bg.brandPressed` + `bg.brandDisabled`** ကို resolve လုပ်နေရမည်။
- [ ] Source == `design/hastads1.0.2.json` (DS 1.0.2)၊ `assets/design-tokens.json` ကို manual မတည်းထားရ။
- [ ] Generator (`design-tokens.mjs`) ကို DS 1.0.2 source ဖြင့် regenerate၊ hand-edit မပါ။

---

## အပိုင်း ၃ — တိကျမှု စံနှုန်း (သတ်မှတ်ချက်)

1. **RED ကို အရင်မြင်ရမည်** — GREEN တစ်ခုတည်းသည် အတည်ပြုခြင်း မဟုတ်။
2. **Committed test ဖြင့်သာ** — scratch/manual pass ကို မရေတွက် (T46 ၏ committed active-token case ကို commit လုပ်ရမည်)။
3. **Reverse control** — guard ကို ဖျက်ပြီး RED ပြန်ဖြစ်ကြောင်း တစ်ခုချင်း သက်သေပြ။
4. **Isolated + synthetic** — shared DB မသုံး၊ fixture မှာ `synthetic` ဖြစ်ကြောင်း log တွင်ထား။
5. **Locale နှစ်ခု + 200% + smallest device** — UI test matrix မလွှတ်ရ။
6. **Scope ကို ဖြတ်တောက်** — Linked Accounts / Connect Gmail သည် S1 acceptance ထဲပါလား ဆုံးဖြတ်၊ S2 ဆို `deferred` မှတ်တမ်းတင် (BLOCKED အဖြစ် မထား)။
7. **T47 baseline** — first-release tag ဖန်တီးမှ တကယ့် previous-tag comparison run ဖြစ်ကြောင်း သက်သေပြ။

---

## အပိုင်း ၄ — Report အစီအစဉ် (ရလဒ်တင်ပြပုံ)

```
Logic:  <ID>  RED->GREEN  <committed? y/n>  <reverse-control y/n>   evidence=<file:line>
UI:     <screen>/<state>  <locale> 200% 320x568  <pass/fail>  golden=<path>
Tokens: normal/pressed/disabled  <resolved?>  source=<DS 1.0.2 path?>
Scope:  <feature>  in-scope S1?  <y/n>  <deferred S2 / blocked reason>
Gate:   T37 <..>  T40 <..>  T41 <..>  T46 <..>  T47 <..>  T48 <..>
Verdict: merge-ready?  yes/no  <unresolved blockers>
```
