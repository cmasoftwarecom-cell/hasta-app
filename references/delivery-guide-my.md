# Hasta — Agent နှင့် GitHub ချိတ်ဆက်ပြီး Prompt အနည်းဆုံးသုံးနည်း (မြန်မာ)

## အကျဉ်း

အရင်က message တစ်ခုပို့တိုင်း `Agent\_Handoff\_Prompt.md` (\~15 KB) ကို paste ပြီး PRD/bundle (\~154 KB) ကို
ပြန် attach တင်ရခဲ့ပါတယ်။ အခု **အခိုက်အတန့်အားလုံး repo ထဲ** ရှိနေပါတယ်:

```
hasta-app/
├── SKILL.md              ← agent စည်းမျဉ်း + default များ (context အားလုံး)
├── PROMPTS.md            ← သုံးရမည့် စာကြောင်းတိုများ
├── .hasta/STATE.md       ← ဘယ်နေရာရောက်ပြီလဲ (agent က ဖတ်ပြီး ပြန်ရေးသည်)
├── references/
│   ├── spec-master.md    ← Hasta\_v1\_Master\_PRD.md ကို ဒီနာမည်ဖြင့် တင်ပါ
│   ├── api-contract.md   ← Hasta\_v1\_API\_Contract.md
│   ├── sprint-prompts.md ← S0–S10 one-liner
│   └── delivery-guide-my.md
└── assets/
    └── design-tokens.json ← Hasta\_v1\_Design\_Tokens.json
```

`SKILL.md` §1 တွင် "စာကြောင်းတစ်ကြောင်း = လက်မှတ်ရေးထိုးပြီးသား အပြည့်အစုံ instruction" ဟု
သတ်မှတ်ထားသဖြင့် agent က spec ပြန်တောင်း၍ မရတော့ပါ။ Ambiguous ဖြစ်လျှင် §5 DEFAULTS ဇယားကို
အသုံးပြုပြီး `\[ASSUMED]` ဖြင့် ဆက်လုပ်သည်။

## ၁။ GitHub repo ပြင်ဆင်ခြင်း

```bash
git clone https://github.com/<user>/hasta-app.git   # private ဖြင့် စတင်ပါ
cd hasta-app
mkdir -p references assets .hasta decisions/adr
cp SKILL.md PROMPTS.md .gitignore .hasta/STATE.md ./
mv Hasta\_v1\_Master\_PRD.md      references/spec-master.md
mv Hasta\_v1\_API\_Contract.md    references/api-contract.md
mv Hasta\_v1\_Design\_Tokens.json assets/design-tokens.json
mv Hasta\_v1\_UI\_Reference.html  docs/ui-reference.html
git add -A \&\& git commit -m "chore: agent skill package (minimal-prompt v2)" \&\& git push
```

Web UI မှ တင်လျှင်: repo → Add file → Upload files → `SKILL.md` တစ်ခုတည်းအရင်တင် → ပြီးလျှင်
`references/`, `assets/`, `.hasta/` ဖိုင်များကို အထက်ပါနာမည်အတိုင်း တင်ပါ (နာမည်မပြောင်းရ)။

## ၂။ Connector ချိတ်ဆက်ခြင်း

1. Perplexity → **Connectors → GitHub** → Authorize → `hasta-app` ကို ရွေးပါ (private repo ဖတ်ခွင့်)။
2. ဤ repo ကို သုံးမည့် project/thread တိုင်းတွင် GitHub connector ဖွင့်ထားသည်ဟု သေချာပါစေ။
3. Token လဲ/permissions ပြောင်းလျှင် `Hasta sync` တစ်ကြောင်းပို့ပြီး state ပြန်ချိန်နှိပ်ပါ။
4. Agent တွင် skill ဖိုင်ကို တိုက်ရိုက်မတင်ရ — repo root `SKILL.md` ကို စာဖတ်ခြင်းအဖြစ် သုံးသည်။

## ၃။ အသုံးပြုနည်း (ပထမ ၃ message)

```
Hasta init
Hasta S0
Hasta status
```

ထို့နောက် `Hasta next` / `Hasta review PR #2` / `Hasta fix T37` စသည်ဖြင့် တစ်ကြောင်းစီ။
အသစ်ဖွင့် thread တိုင်း `Hasta init` တစ်ကြောင်းတည်း — ဖိုင် ပြန် attach မတင်ရ။

## ၄။ စည်းမျဉ်း ၄ ခု (agent အားထားနိုင်အောင်)

|စည်းမျဉ်း|နေရာ|
|-|-|
|Sprint တစ်ခု = PR တစ်ခု၊ ≤ 400 lines (bootstrap PR #1 လွှဲ exemptions)|`SKILL.md` §5|
|Exit criteria = mapped test IDs (T1–T48) စိမ်း|`SKILL.md` §6/§7|
|`\[PROPOSAL]` values = remote config သာ၊ hard-code မလုပ်ရ|`SKILL.md` §7.10|
|Secrets (OAuth client, FCM/APNs, AWS) ကို agent ထံ ဘယ်တော့မှ မပို့ရ — `.env.example` placeholder သာ|`SKILL.md` §9|

## ၅။ ဖိုင်အဟောင်းများ

|ဖိုင်|အခြေအနေ|
|-|-|
|`Hasta\_v1\_Agent\_Handoff\_Prompt.md`|**မတင်ရတော့** — `SKILL.md` က အစားထိုး။ repo `docs/archive/` တွင် သိမ်းရုံ|
|`Hasta\_v1\_BUNDLE\_AllInOne.md`|archive သာ — paste မလုပ်ရ (`SKILL.md` §1.4)|
|`Hasta\_v1\_Index.md`|archive သာ|
|`Hasta\_Sprint1\_Review\_Sprint2.md`|rulings များကို `.hasta/STATE.md` + `decisions/adr/` ထဲ ပြောင်းပြီး။ ပြင်ဆင်မှုတိုင်း `Hasta fix <id>`|
|`Hasta\_Myanmar\_Copy\_Review\_Brief.md`|`references/` ထဲ ခေါ်ဝင်နိုင် (copy review လိုတိုင်း `Hasta review copy`)|

## ၆။ Problem တက်လျှင်

|ပြဿနာ|ဖြေရှင်း|
|-|-|
|Agent က spec ပြန်တောင်းသည်|`SKILL.md §1 read လုပ်ပါ။ repo ထဲမှာပဲ အဖြေရှိတယ်။` ပို့ပါ၊ ပြီးလျှင် `Hasta sync`|
|ဘာပြီးပြီလဲ မသိရ|`Hasta status` (state file ကို HEAD နှင့် ချိန်ပေးသည်)|
|Thread အဟောင်း ပျောက်သည်|ပြဿနာ မဟုတ်တော့ — state သည် `.hasta/STATE.md` တွင် ရှိ|
|Gate အသစ် ထပ်စရာ|SPEC bump ပြီး STATE ၏ "Gates currently enforced" သာ ဖြည့်ပါ|
|Repo ကြီးလာသည်|`.gitignore` သုံးပြီး build artifact ဖယ်ပါ；spec/code ခွဲရင် `hasta-docs` repo ခွဲ၍ `SKILL.md` တွင် path ပြောင်းပါ|



