# Hasta — Minimal Prompt Library (v2)

ဒီဖိုင်တစ်ခုတည်းသောက်ရုံနဲ့ GitHub repo ကို အသုံးပြုနိုင်ပါတယ်။ **အရှည်ဆုံး prompt = စာကြောင်း ၁ ကြောင်း။**
You only ever need one line. The repo (SKILL.md + references/ + .hasta/STATE.md) carries all the context.

---

## 0. First message in a brand-new thread (the only prompt that is 3 lines)

```
Hasta init. Read SKILL.md and .hasta/STATE.md, then implement the next open sprint.
Branch off main, one PR, mapped test IDs. Reply ≤ 5 lines then the code.
```

ရetrofit: အသစ်ဖွင့် thread တိုင်းမှာ `Hasta init` တစ်ကြောင်းတည်း။ ဘာ spec မှ ပြန် attach မတင်ရ။

---

## 1. Daily one-liners

| လုပ်ချင်တာ | Prompt (copy ပါ) |
| --- | --- |
| Sprint 0 scaffold | `Hasta S0` |
| Sprint N ပြီးမြောက်အောင် | `Hasta S3` (S0–S10) |
| နောက် sprint သို့ | `Hasta next` |
| ဘယ်အခြေအနေရောက်လဲ | `Hasta status` |
| PR/branch သုံးသပ် | `Hasta review PR #2` |
| Gate တစ်ခု ပြင် | `Hasta fix T37` |
| DDL / migration | `Hasta migrate accounts` |
| Screen တစ်ခု UI | `Hasta ui welcome` |
| Endpoint | `Hasta api POST /v1/auth/guest` |
| WS event | `Hasta ws chat.message` |
| Test | `Hasta test T46` |
| ADR | `Hasta adr 0007 token bg.brand` |
| State ကို repo နှင့် ချိန် | `Hasta sync` |
| SPEC version တင် | `Hasta spec bump 1.0.2` |
| ရပ် | `Hasta stop` |

---

## 2. Sprint 0–10 အစဉ် (အလိုအလျောက် `next` ဖြင့် တက်နိုင်)

```
Hasta S0
Hasta S1
Hasta S2
Hasta S3
...
Hasta S10
```
Exit criteria မှာ PR merge ဖြစ်ပြီး mapped test IDs စိမ်းနေရမည် — agent ကို သတ်မှတ်ခိုင်းစရာမလိုအောင် `SKILL.md` §5/§7 တွင် ဖတ်ထားသည်။

---

## 3. Review → Fix → Next (အကျဆုံး စာကြောင်း ၃ ဆင့်)

```
Hasta review PR #2
Hasta fix <P0 id>            (အကြိမ်အရေအတွက် လိုသလောက်)
Hasta next
```

`Hasta_Sprint1_Review_Sprint2.md` လို ဖိုင်ကြီး paste လုပ်စရာ မလိုတော့ပါ — rulings များကို
`decisions/adr/` + `.hasta/STATE.md` ထဲ သိမ်းထားသဖြင့် `Hasta review PR #2` တစ်ကြောင်းတည်း ဖြစ်ပြီးပါတယ်။

---

## 4. ဘယ်အခါမှ လိုအပ်တော့မည့်အရာများ (removed)

| အဟောင်း (ဖျက်ပြီး) | အစားထိုး |
| --- | --- |
| `=== PROMPT START … END ===` block (~15 KB paste) | `SKILL.md` repo တွင်ရှိ → `Hasta init` |
| `Hasta_v1_BUNDLE_AllInOne.md` attach (154 KB) | `references/spec-master.md` ကို agent က ဖတ်သည် |
| Sprint per-paragraph instructions | `references/sprint-prompts.md` 1-liner |
| "Sprint N သာ လုပ်ပါ" ကို ထပ်ထပ်သတိပေးခြင်း | `SKILL.md` §5 sprint-scope default |
| Context ပျောက်တိုင်း အသစ်ပြန်ရေး | `.hasta/STATE.md` |

---

## 5. Agent က context တောင်းလာရင် (guard rail)

```
SKILL.md §1 read လုပ်ပါ။ repo ထဲမှာပဲ အဖြေရှိတယ်။
```
(English: "Read SKILL.md §1. The answer is already in the repo.")

---

## 6. အဆုံးစွန် cheat sheet (ဖုန်းမှတ်ထားလောက်အောင်)

`init` · `S<n>` · `next` · `status` · `review PR #n` · `fix <x>` · `migrate` · `ui` · `api` · `ws` · `test` · `adr` · `sync` · `spec bump` · `stop`
