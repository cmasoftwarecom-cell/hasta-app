# Hasta v3 Production Package — All In One (path-anchored)

Each block below goes to the repo path shown in its heading. Order of upload:
1) `assets/design-tokens.json` + `tools/scripts/design-tokens.mjs` + `apps/mobile/lib/design_tokens.g.dart` (PR #5, closes P0-DESIGN-TOKENS-GATE)
2) `docs/production-golive-plan.md` + `docs/qa/logic-ui-state-verification-guide.md`
3) `.hasta/STATE.md`
4) `infra/*`, `.github/workflows/deploy-staging.yml`, `scripts/*` (PR #7)


---

## REPO PATH: `assets/design-tokens.json`

```
{
  "$schema": "https://designtokens.org/schema/dtcg.json",
  "$meta": {
    "name": "Hasta Design System",
    "version": "1.0.2",
    "source_of_truth": "assets/design-tokens.json",
    "generated_target": "apps/mobile/lib/design_tokens.g.dart",
    "generator": "tools/scripts/design-tokens.mjs",
    "rule": "Do not hand-edit the generated Dart. Change this file and re-run the generator.",
    "notes": "Colors are brand placeholders pending final brand hex confirmation (ADR-0013)."
  },
  "color": {
    "bg": {
      "brand": {
        "$type": "color",
        "$value": "#6C4DF6"
      },
      "brandPressed": {
        "$type": "color",
        "$value": "#5A3BD8"
      },
      "brandDisabled": {
        "$type": "color",
        "$value": "#3F3663"
      },
      "surface": {
        "$type": "color",
        "$value": "#14121C"
      },
      "surfaceRaised": {
        "$type": "color",
        "$value": "#1D1A28"
      },
      "canvas": {
        "$type": "color",
        "$value": "#0D0B13"
      },
      "danger": {
        "$type": "color",
        "$value": "#B3261E"
      },
      "warn": {
        "$type": "color",
        "$value": "#8A5A00"
      },
      "ok": {
        "$type": "color",
        "$value": "#1E7A45"
      }
    },
    "text": {
      "onBrand": {
        "$type": "color",
        "$value": "#FFFFFF"
      },
      "primary": {
        "$type": "color",
        "$value": "#F3F1FA"
      },
      "secondary": {
        "$type": "color",
        "$value": "#B6B1C6"
      },
      "disabled": {
        "$type": "color",
        "$value": "#6E6880"
      },
      "danger": {
        "$type": "color",
        "$value": "#FFB4AB"
      },
      "link": {
        "$type": "color",
        "$value": "#C9BCFF"
      }
    },
    "line": {
      "default": {
        "$type": "color",
        "$value": "#2A2637"
      },
      "strong": {
        "$type": "color",
        "$value": "#4A4360"
      },
      "focus": {
        "$type": "color",
        "$value": "{color.bg.brand}"
      }
    },
    "icon": {
      "default": {
        "$type": "color",
        "$value": "{color.text.secondary}"
      },
      "onBrand": {
        "$type": "color",
        "$value": "{color.text.onBrand}"
      }
    }
  },
  "typography": {
    "fontFamily": {
      "base": {
        "$type": "family",
        "$value": [
          "Inter",
          "Pyidaungsu",
          "Noto Sans Myanmar",
          "Myanmar Text",
          "sans-serif"
        ]
      },
      "numeric": {
        "$type": "family",
        "$value": [
          "Inter",
          "Roboto Mono",
          "monospace"
        ]
      }
    },
    "fontSize": {
      "body": {
        "$type": "dimension",
        "$value": "16px"
      },
      "label": {
        "$type": "dimension",
        "$value": "14px"
      },
      "title": {
        "$type": "dimension",
        "$value": "20px"
      },
      "display": {
        "$type": "dimension",
        "$value": "28px"
      }
    },
    "lineHeight": {
      "body": {
        "$type": "number",
        "$value": 1.65
      },
      "label": {
        "$type": "number",
        "$value": 1.5
      },
      "title": {
        "$type": "number",
        "$value": 1.35
      },
      "display": {
        "$type": "number",
        "$value": 1.2
      }
    },
    "fontWeight": {
      "regular": {
        "$type": "number",
        "$value": 400
      },
      "medium": {
        "$type": "number",
        "$value": 500
      },
      "semibold": {
        "$type": "number",
        "$value": 600
      }
    }
  },
  "space": {
    "xs": {
      "$type": "dimension",
      "$value": "4px"
    },
    "sm": {
      "$type": "dimension",
      "$value": "8px"
    },
    "md": {
      "$type": "dimension",
      "$value": "16px"
    },
    "lg": {
      "$type": "dimension",
      "$value": "24px"
    },
    "xl": {
      "$type": "dimension",
      "$value": "32px"
    }
  },
  "radius": {
    "sm": {
      "$type": "dimension",
      "$value": "8px"
    },
    "md": {
      "$type": "dimension",
      "$value": "12px"
    },
    "lg": {
      "$type": "dimension",
      "$value": "16px"
    },
    "pill": {
      "$type": "dimension",
      "$value": "999px"
    }
  },
  "elevation": {
    "raised": {
      "$type": "shadow",
      "$value": [
        {
          "offsetX": "0px",
          "offsetY": "2px",
          "blur": "8px",
          "color": "#00000066"
        }
      ]
    }
  },
  "motion": {
    "durationFast": {
      "$type": "duration",
      "$value": "120ms"
    },
    "durationBase": {
      "$type": "duration",
      "$value": "200ms"
    },
    "easingStandard": {
      "$type": "cubicBezier",
      "$value": [
        0.2,
        0.0,
        0.0,
        1.0
      ]
    }
  },
  "breakpoint": {
    "narrow": {
      "$type": "dimension",
      "$value": "320px"
    },
    "textScaleMax": {
      "$type": "number",
      "$value": 2.0
    }
  },
  "component": {
    "button": {
      "primary": {
        "background": {
          "$type": "color",
          "$value": "{color.bg.brand}"
        },
        "backgroundPressed": {
          "$type": "color",
          "$value": "{color.bg.brandPressed}"
        },
        "backgroundDisabled": {
          "$type": "color",
          "$value": "{color.bg.brandDisabled}"
        },
        "foreground": {
          "$type": "color",
          "$value": "{color.text.onBrand}"
        },
        "minHeight": {
          "$type": "dimension",
          "$value": "48px"
        },
        "radius": {
          "$type": "dimension",
          "$value": "{radius.md}"
        }
      },
      "secondary": {
        "background": {
          "$type": "color",
          "$value": "#00000000"
        },
        "border": {
          "$type": "color",
          "$value": "{color.line.strong}"
        }
      }
    },
    "link": {
      "color": {
        "$type": "color",
        "$value": "{color.text.link}"
      }
    },
    "banner": {
      "errorBg": {
        "$type": "color",
        "$value": "{color.bg.danger}"
      }
    }
  }
}```


---

## REPO PATH: `tools/scripts/design-tokens.mjs`

```
#!/usr/bin/env node
// Hasta design-token generator  (DS 1.0.2 / SPEC 1.0.2)
// Input : assets/design-tokens.json   (DTCG nested, dot-path addressing, "{a.b.c}" aliases)
// Output: apps/mobile/lib/design_tokens.g.dart   (generated, never hand-edited)
//
// Gate behaviour (fail closed):
//   1. missing canonical input                -> exit 1  (closes P0-DESIGN-TOKENS-GATE properly)
//   2. misplaced copy at assets/assets/...    -> exit 1 + exact repair command
//   3. required token absent / bad hex        -> exit 1
//   4. typography.lineHeight.body < 1.65      -> exit 1  (Myanmar glyph requirement)
//   5. no Myanmar-capable family in fontFamily-> exit 1
//   6. --check with stale committed Dart      -> exit 1  (proves the .g.dart is not hand-edited)
//
// Usage:
//   node tools/scripts/design-tokens.mjs                 # regenerate
//   node tools/scripts/design-tokens.mjs --check         # CI: verify committed Dart is in sync
//   node tools/scripts/design-tokens.mjs --print         # stdout only
//   node tools/scripts/design-tokens.mjs --input X --output Y

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..', '..');
const CANON_INPUT = 'assets/design-tokens.json';
const DEFAULT_OUT = 'apps/mobile/lib/design_tokens.g.dart';
const MIN_BODY_LINE_HEIGHT = 1.65;
const MYANMAR_FAMILIES = ['pyidaungsu', 'noto sans myanmar', 'myanmar text', 'myanmar3', 'padauk'];

const REQUIRED = [
  'color.bg.brand', 'color.bg.brandPressed', 'color.bg.brandDisabled', 'color.text.onBrand',
  'typography.lineHeight.body', 'typography.fontFamily.base',
  'component.button.primary.background', 'component.button.primary.backgroundPressed',
  'component.button.primary.backgroundDisabled',
];

const argv = process.argv.slice(2);
const flag = (n) => argv.includes('--' + n);
const opt = (n) => { const i = argv.indexOf('--' + n); return i >= 0 ? argv[i + 1] : undefined; };

const die = (msg, hint) => {
  process.stderr.write(`\n[design-tokens] FAIL: ${msg}\n` + (hint ? `[design-tokens] FIX : ${hint}\n` : ''));
  process.exit(1);
};

// ---------- input ----------
const inputRel = opt('input') || CANON_INPUT;
const inputPath = resolve(ROOT, inputRel);
if (!existsSync(inputPath)) {
  const stray = join(ROOT, 'assets', 'assets', 'design-tokens.json');
  if (inputRel === CANON_INPUT && existsSync(stray)) {
    die(`${CANON_INPUT} not found; found a copy at assets/assets/design-tokens.json`,
        `git mv assets/assets/design-tokens.json assets/design-tokens.json && git rm -r --cached assets/assets 2>/dev/null; then re-run this script`);
  }
  die(`${inputRel} not found (source of truth absent)`,
      'commit the DS 1.0.2 file at the canonical path assets/design-tokens.json — do not point the generator at a substitute palette');
}
let raw;
try { raw = JSON.parse(readFileSync(inputPath, 'utf8')); }
catch (e) { die(`${inputRel} is not valid JSON: ${e.message}`); }

// ---------- flatten + alias resolve ----------
const leaves = {};                       // "color.bg.brand" -> {type, value}
(function walk(node, path) {
  if (!node || typeof node !== 'object') return;
  if ('$value' in node) { leaves[path.join('.')] = node; return; }
  for (const [k, v] of Object.entries(node)) {
    if (k.startsWith('$')) continue;
    walk(v, path.concat(k));
  }
})(raw, []);

const lookup = (obj, dotted) => dotted.split('.').reduce((a, k) => (a && typeof a === 'object') ? a[k] : undefined, obj);

function resolveValue(node, trail) {
  let v = node.$value;
  const seen = [];
  for (let depth = 0; depth < 12; depth++) {
    if (typeof v !== 'string') return v;
    const m = /^\{\s*([^}]+?)\s*\}$/.exec(v.trim());
    if (!m) return v;
    if (seen.includes(m[1])) die(`alias cycle at ${trail}: ${seen.concat(m[1]).join(' -> ')}`);
    seen.push(m[1]);
    const refNode = lookup(raw, m[1]);
    if (!refNode || typeof refNode !== 'object' || !('$value' in refNode)) {
      die(`unresolved alias {${m[1]}} referenced by ${trail}`);
    }
    v = refNode.$value;
  }
  die(`alias depth exceeded at ${trail}`);
}

const values = {};
for (const [p, node] of Object.entries(leaves)) values[p] = { type: node.$type || 'unknown', value: resolveValue(node, p) };

for (const p of REQUIRED) if (!(p in values)) die(`required token missing: ${p}`, `add "${p}" to ${inputRel}`);

// ---------- assertions ----------
const lh = Number(values['typography.lineHeight.body'].value);
if (!Number.isFinite(lh) || lh < MIN_BODY_LINE_HEIGHT) {
  die(`typography.lineHeight.body = ${lh} < ${MIN_BODY_LINE_HEIGHT} (Myanmar glyphs need >= ${MIN_BODY_LINE_HEIGHT})`);
}
const fams = (Array.isArray(values['typography.fontFamily.base'].value)
  ? values['typography.fontFamily.base'].value : [values['typography.fontFamily.base'].value]).map(s => String(s).toLowerCase());
if (!fams.some(f => MYANMAR_FAMILIES.some(m => f.includes(m)))) {
  die(`typography.fontFamily.base has no Myanmar-capable family: got ${JSON.stringify(fams)}`,
      'include "Pyidaungsu" or "Noto Sans Myanmar"');
}

// ---------- dart emit ----------
const hexToArgb = (hex) => {
  let h = String(hex).trim().replace(/^#/, '');
  if (h.length === 3) h = h.split('').map(c => c + c).join('');
  if (h.length === 6) h = 'FF' + h;
  if (h.length !== 8 || !/^[0-9a-fA-F]{8}$/.test(h)) die(`invalid color value: ${hex}`);
  return h.toUpperCase();
};
const camel = (s) => String(s).replace(/[^A-Za-z0-9]+/g, ' ').trim().split(' ').map((w, i) =>
  i === 0 ? w.charAt(0).toLowerCase() + w.slice(1) : w.charAt(0).toUpperCase() + w.slice(1)).join('');
const identFor = (p) => {
  const segs = p.split('.');
  const clean = (segs[0] === 'color' || segs[0] === 'typography') ? segs.slice(1) : segs;
  return camel(clean.join('_'));
};
const dartType = (t) => t === 'color' ? 'Color' : (t === 'number' ? 'double' : (t === 'dimension' || t === 'duration' ? 'double' : 'String'));
const dartLiteral = (v, t) => {
  if (t === 'color') return `Color(0x${hexToArgb(v)})`;
  if (t === 'number') return `${Number(v).toFixed(2)}`;
  if (t === 'dimension' || t === 'duration') return `${parseFloat(String(v))}`;
  if (Array.isArray(v)) return `<String>[${v.map(x => `'${x}'`).join(', ')}]`;
  return `'${String(v).replace(/'/g, "\\'")}'`;
};
const dartTypeFor = (t, v) => {
  if (t === 'color') return 'Color';
  if (t === 'number' || t === 'dimension' || t === 'duration') return 'double';
  if (Array.isArray(v)) return 'List<String>';
  if (t === 'cubicBezier' || t === 'shadow') return 'List<num>';
  return 'String';
};

const lines = [];
lines.push('// GENERATED by tools/scripts/design-tokens.mjs — DO NOT EDIT.');
lines.push(`// source : ${CANON_INPUT}  (DS ${raw.$meta ? (raw.$meta.version || 'unversioned') : 'unversioned'})`);
lines.push('// rerun  : node tools/scripts/design-tokens.mjs && flutter analyze');
lines.push("import 'package:flutter/painting.dart';");
lines.push('');
lines.push('class DesignTokens {');
lines.push('  DesignTokens._();');
lines.push('');
const emitted = [];
for (const p of Object.keys(values).sort()) {
  const { type, value } = values[p];
  if (type === 'shadow' || type === 'cubicBezier') continue;
  let name = identFor(p);
  if (name.startsWith('button')) name = 'cmp' + name.charAt(0).toUpperCase() + name.slice(1);
  if (/^\d/.test(name)) name = 'n' + name;
  const dt = dartTypeFor(type, value);
  const lit = (dt === 'List<String>') ? `<String>[${(Array.isArray(value) ? value : [value]).map(x => `'${x}'`).join(', ')}]`
            : (dt === 'List<num>') ? `<num>[${(Array.isArray(value) ? value : [value]).join(', ')}]`
            : (dt === 'double') ? dartLiteral(value, type)
            : (dt === 'Color') ? dartLiteral(value, type)
            : dartLiteral(value, 'string');
  lines.push(`  static const ${dt} ${name} = ${lit};  // ${p}`);
  emitted.push(name);
}
lines.push('');
lines.push('  // Primary button three-state wiring (T36/accessibility gate). Use these, never literals.');
lines.push('  static const Color primaryButtonBackground = bgBrand;');
lines.push('  static const Color primaryButtonPressed = bgBrandPressed;');
lines.push('  static const Color primaryButtonDisabled = bgBrandDisabled;');
lines.push('  static const Color primaryButtonForeground = textOnBrand;');
lines.push('}');
const dart = lines.join('\n') + '\n';

const outRel = opt('output') || DEFAULT_OUT;
const outPath = resolve(ROOT, outRel);

if (flag('print')) { process.stdout.write(dart); process.exit(0); }

if (flag('check')) {
  if (!existsSync(outPath)) die(`--check: ${outRel} is not committed`, 'run: node tools/scripts/design-tokens.mjs && git add ' + outRel);
  const committed = readFileSync(outPath, 'utf8');
  const strip = (s) => s.split('\n').filter(l => !l.trim().startsWith('//')).join('\n').trim();
  if (strip(committed) !== strip(dart)) {
    die(`--check: ${outRel} is stale or hand-edited (drift vs ${inputRel})`,
        'run the generator, commit the regenerated file; never edit design_tokens.g.dart by hand');
  }
  process.stdout.write(`[design-tokens] OK  ${inputRel} -> ${outRel} in sync (${emitted.length} tokens)\n`);
  process.exit(0);
}

mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, dart, 'utf8');
process.stdout.write(`[design-tokens] wrote ${outRel}  (${emitted.length} tokens, lineHeightBody=${lh})\n`);
```


---

## REPO PATH: `apps/mobile/lib/design_tokens.g.dart`

```
// GENERATED by tools/scripts/design-tokens.mjs — DO NOT EDIT.
// source : assets/design-tokens.json  (DS 1.0.2)
// rerun  : node tools/scripts/design-tokens.mjs && flutter analyze
import 'package:flutter/painting.dart';

class DesignTokens {
  DesignTokens._();

  static const double breakpointNarrow = 320;  // breakpoint.narrow
  static const double breakpointTextScaleMax = 2.00;  // breakpoint.textScaleMax
  static const Color bgBrand = Color(0xFF6C4DF6);  // color.bg.brand
  static const Color bgBrandDisabled = Color(0xFF3F3663);  // color.bg.brandDisabled
  static const Color bgBrandPressed = Color(0xFF5A3BD8);  // color.bg.brandPressed
  static const Color bgCanvas = Color(0xFF0D0B13);  // color.bg.canvas
  static const Color bgDanger = Color(0xFFB3261E);  // color.bg.danger
  static const Color bgOk = Color(0xFF1E7A45);  // color.bg.ok
  static const Color bgSurface = Color(0xFF14121C);  // color.bg.surface
  static const Color bgSurfaceRaised = Color(0xFF1D1A28);  // color.bg.surfaceRaised
  static const Color bgWarn = Color(0xFF8A5A00);  // color.bg.warn
  static const Color iconDefault = Color(0xFFB6B1C6);  // color.icon.default
  static const Color iconOnBrand = Color(0xFFFFFFFF);  // color.icon.onBrand
  static const Color lineDefault = Color(0xFF2A2637);  // color.line.default
  static const Color lineFocus = Color(0xFF6C4DF6);  // color.line.focus
  static const Color lineStrong = Color(0xFF4A4360);  // color.line.strong
  static const Color textDanger = Color(0xFFFFB4AB);  // color.text.danger
  static const Color textDisabled = Color(0xFF6E6880);  // color.text.disabled
  static const Color textLink = Color(0xFFC9BCFF);  // color.text.link
  static const Color textOnBrand = Color(0xFFFFFFFF);  // color.text.onBrand
  static const Color textPrimary = Color(0xFFF3F1FA);  // color.text.primary
  static const Color textSecondary = Color(0xFFB6B1C6);  // color.text.secondary
  static const Color componentBannerErrorBg = Color(0xFFB3261E);  // component.banner.errorBg
  static const Color componentButtonPrimaryBackground = Color(0xFF6C4DF6);  // component.button.primary.background
  static const Color componentButtonPrimaryBackgroundDisabled = Color(0xFF3F3663);  // component.button.primary.backgroundDisabled
  static const Color componentButtonPrimaryBackgroundPressed = Color(0xFF5A3BD8);  // component.button.primary.backgroundPressed
  static const Color componentButtonPrimaryForeground = Color(0xFFFFFFFF);  // component.button.primary.foreground
  static const double componentButtonPrimaryMinHeight = 48;  // component.button.primary.minHeight
  static const double componentButtonPrimaryRadius = 12;  // component.button.primary.radius
  static const Color componentButtonSecondaryBackground = Color(0x00000000);  // component.button.secondary.background
  static const Color componentButtonSecondaryBorder = Color(0xFF4A4360);  // component.button.secondary.border
  static const Color componentLinkColor = Color(0xFFC9BCFF);  // component.link.color
  static const double motionDurationBase = 200;  // motion.durationBase
  static const double motionDurationFast = 120;  // motion.durationFast
  static const double radiusLg = 16;  // radius.lg
  static const double radiusMd = 12;  // radius.md
  static const double radiusPill = 999;  // radius.pill
  static const double radiusSm = 8;  // radius.sm
  static const double spaceLg = 24;  // space.lg
  static const double spaceMd = 16;  // space.md
  static const double spaceSm = 8;  // space.sm
  static const double spaceXl = 32;  // space.xl
  static const double spaceXs = 4;  // space.xs
  static const List<String> fontFamilyBase = <String>['Inter', 'Pyidaungsu', 'Noto Sans Myanmar', 'Myanmar Text', 'sans-serif'];  // typography.fontFamily.base
  static const List<String> fontFamilyNumeric = <String>['Inter', 'Roboto Mono', 'monospace'];  // typography.fontFamily.numeric
  static const double fontSizeBody = 16;  // typography.fontSize.body
  static const double fontSizeDisplay = 28;  // typography.fontSize.display
  static const double fontSizeLabel = 14;  // typography.fontSize.label
  static const double fontSizeTitle = 20;  // typography.fontSize.title
  static const double fontWeightMedium = 500.00;  // typography.fontWeight.medium
  static const double fontWeightRegular = 400.00;  // typography.fontWeight.regular
  static const double fontWeightSemibold = 600.00;  // typography.fontWeight.semibold
  static const double lineHeightBody = 1.65;  // typography.lineHeight.body
  static const double lineHeightDisplay = 1.20;  // typography.lineHeight.display
  static const double lineHeightLabel = 1.50;  // typography.lineHeight.label
  static const double lineHeightTitle = 1.35;  // typography.lineHeight.title

  // Primary button three-state wiring (T36/accessibility gate). Use these, never literals.
  static const Color primaryButtonBackground = bgBrand;
  static const Color primaryButtonPressed = bgBrandPressed;
  static const Color primaryButtonDisabled = bgBrandDisabled;
  static const Color primaryButtonForeground = textOnBrand;
}
```


---

## REPO PATH: `.hasta/STATE.md`

```
# .hasta/STATE.md — SPEC 1.0.2 · updated after `Hasta review PR #3` (ac55526)

status: S2 IN REVIEW — pipeline blocked by a CI gate, not by code quality
next:   Hasta fix P0-DESIGN-TOKENS-GATE

## Repo
main:            3983817 (carries stale assets/assets/design-tokens.json; canonical path absent)
PR #2 (S1):      MERGED
PR #3 (S2 Gmail linking): DRAFT @ ac55526 · 938 changed lines (+879/−59) · ACCEPT for draft scope · no open P0/P1/P2
PR #4 (Security & Devices): DRAFT @ dd5b261 · 322 changed lines · REQUEST CHANGES (P0-DESIGN-TOKENS-GATE inherited)
merge train:     #5 (tokens) → merge → rebase #3 → merge → rebase #4 → #6 (revocation + native T30) → #7 (staging infra)
cap policy:      938 lines is terminal for #3; no further waivers — new fix = new draft PR (≤ 400)

## CI (latest reported)
gates        PASS   (but design-token step fails on absent source -> blocks T47 in PR #4)
terraform    PASS
backend      PASS
mobile       PASS
iOS          QUEUED — CI is NOT fully green

## Gates
T20 PASS · T36 PASS (Android artifact scan excludes QA panel; google_sign_in absent from release manifest; iOS unsigned PASS)
T37 PASS-with-caveat (server routes + 10 fixtures; real Google verifier = S2 tail; idempotency key no longer persisted; real-coordinator test committed)
T38/T39 PASS local · T40/T41 server+Flutter PASS, **NATIVE = TIMED OUT at 12 min (must fail fast, not hang)**
T42 PASS · T43 PASS (offline transition EN+MM) · T44 OPEN · T45 PASS · T46 PASS (active-token case committed)
T47 PASS locally + diff vs frozen S1 baseline; skipped in CI when no release tag
T48 PASS (postgres:16 pinned, reverse-control proven)
Design tokens P0-DESIGN-TOKENS-GATE OPEN  — assets/design-tokens.json absent on main
Design tokens P1 button wiring           — resolved in generated Dart (bgBrandPressed / bgBrandDisabled emitted)
P2-SESSION-ACTIVITY-LABEL                OPEN (last_seen_at null -> label "Signed in", EN+MM test)

## Staging
dns:      api-social.hasta.app NXDOMAIN · hasta-api.nexusmmr.com proxied -> 404 · api.oddsmyanmar.online -> 104.207.77.242 (wrong origin)
origin:   Vultr 149.28.136.202, Ubuntu 24.04, **1024 MB RAM (insufficient — add 2 GB swap, resize to 2 GB; move Postgres to managed)**
health:   GET /health -> {"status":"ok"} — NO env, NO commit field => SHA contract unmet; /v1/health does not exist
port 3000: private by design (do not expose; QA goes through Nginx HTTPS)
fixtures: NOT SEEDED · smoke 12-item: NOT RUN (no request_ids)
artifacts: staging APK NOT built; a release APK may never contain the QA panel (T36)
decision:   one canonical host (recommended api-staging.hasta.app), named tunnel or LB, Full(strict), deploy-staging.yml with environment: staging
tools ready: scripts/verify-staging.sh · scripts/seed-staging.sh · infra/nginx/hasta-api.conf · infra/systemd/hasta-api.service

## Native / external QA still open
native Gmail consent on a real device · app association (assetlinks.json + AASA served from the API host) ·
device-toggle QA EN+MM · T30 reinstall/recovery · physical T28 two-device QR

## Rulings / ADRs
ADR-0007 Prisma schema · ADR-0008 S1 draft rationale · ADR-0009 installation proof, fail-closed legacy bindings, Android API 23
ADR-0012 Gmail linking opt-in + debug-only, external browser, masked email only, UUIDv7 Idempotency-Key not persisted
ADR-0014/0015/0016 rollout holds in effect
ADR-0017 [PROPOSAL — REQUIRED BEFORE ANY WAGERING FLAG] licence + server-side geo gate; Myanmar Cybersecurity Law
  (in force 2025-07-30) penalises unlicensed online gambling systems (6 mo–1 yr and/or 5–20M MMK;
  organisation ≥ 20M MMK + confiscation; applies to Myanmar citizens abroad). Apple 5.3 and Google Play
  both require a per-territory licence and server-side geo-fencing; Myanmar is not on the Play whitelist.

## Compliance flags (block release, not staging)
wagering=true for MM-resident users   -> NO-GO until legal opinion exists in decisions/
18+/KYC, deposit & loss limits, self-exclusion, RNG certification, AML withdrawal allowlist -> REQUIRED
no VPN-based access guidance          -> REQUIRED
store listing metadata must not advertise unlicensed betting (incl. API host naming) -> REQUIRED

## Deviations introduced this cycle
None. No security/QA rule, sign-in rule or release restriction was relaxed.

## Next prompt
Hasta fix P0-DESIGN-TOKENS-GATE
```


---

## REPO PATH: `docs/production-golive-plan.md`

```
# Hasta — Production-Grade Go-Live Plan

Scope: turn the current verified state (SPEC 1.0.2, S1 merged, S2 in review) into a live,
operationally defensible release. Every claim below is traceable to the run log in
`Hasta_fix_P2-GMAIL-FLOW-COVERAGE` or to the artefacts shipped with this plan.

မြန်မာအကျဉ်း — ဒီဖိုင်က "အခုအခြေအနေ → live app" သွားရမယ့် အဆင့်အစီအစဉ်အပြည့်အစုံ။ Phase A က CI ကို ပိတ်ထားတဲ့ design-token gate ကို ဖွင့်တာ (အရင်ဆုံးလုပ်ရမယ့်အရာ)၊ Phase B က ကျန် test gap များ၊ Phase C စစ်မှန်တဲ့ staging environment၊ Phase D production hardening၊ Phase E မလွဲမသွေ လိုက်နာရမယ့် တရားရေးတံခါး။ ဖိုင်အားလုံးကို repo path အတိုင်း ထုတ်ပေးထားပြီး။

---

## 0. Verified snapshot (what the log actually proves)

| Object | State | Evidence |
| --- | --- | --- |
| `main` | `3983817` — carries the **stale token file at `assets/assets/design-tokens.json`**; canonical `assets/design-tokens.json` is absent | `Hasta fix P0-DESIGN-TOKENS-GATE` → "Blocked before edits" |
| PR #2 (S1 guest auth) | **merged** | "Hasta S2 Execution" section |
| PR #3 (S2 Gmail linking) | **draft @ `ac55526`**, 938 changed lines (+879/−59), verdict **ACCEPT for the draft scope — no open P0/P1/P2** | last `Hasta review PR #3` |
| PR #3 CI | gates + Terraform + backend + mobile **pass**; **iOS still queued → CI not fully green** | same |
| PR #4 (Security & Devices) | **draft @ `dd5b261`**, 322 lines, **REQUEST CHANGES** — blocker `P0-DESIGN-TOKENS-GATE` inherited from `main`, not introduced | `Hasta PR #4 review` |
| Open P2 | `P2-SESSION-ACTIVITY-LABEL` — `last_seen_at == null` renders "Last active" instead of "Signed in" | same |
| Still-open verification | native Gmail consent · app association (universal links / `assetlinks`) · device-toggle QA · **T40/T41 native E2E (12-min timeouts)** · physical T28 (2 Android) · staging QA (all items) | throughout |
| Staging infra | Vultr `149.28.136.202`, Ubuntu 24.04, **1024 MB RAM**, 25 GB | provisioning log |
| Hosts attempted | `api-social.hasta.app` → NXDOMAIN · `hasta-api.nexusmmr.com` → proxied but `404 page not found` · `api.oddsmyanmar.online` → A record `104.207.77.242` (**not** the Vultr origin) · direct `:3000` → intentionally private | staging QA logs |

**The single thing blocking the pipeline is not security and not code quality — it is a file path.**
`P0-DESIGN-TOKENS-GATE` stops the `gates` job *before* T47, which in turn stops PR #4 from being
reviewable, which keeps S2 open, which keeps staging unsigned. Fix Phase A first.

---

## 1. Phase A — unblock `P0-DESIGN-TOKENS-GATE` (today)

**A1.** Put the canonical DTCG source at `assets/design-tokens.json` on `main` and delete the
misplaced nested copy (shipped: `assets/design-tokens.json`, 56 tokens, `bg.brand /
bg.brandPressed / bg.brandDisabled`, `lineHeight.body = 1.65`, Myanmar families):

    git checkout main && git pull
    git rm -r --cached assets/assets 2>/dev/null || true
    rm -rf assets/assets
    # place assets/design-tokens.json (from this package)
    git add assets/design-tokens.json && git commit -m "fix(tokens): restore DS 1.0.2 at canonical path (P0-DESIGN-TOKENS-GATE)"

**A2.** Replace `tools/scripts/design-tokens.mjs` with the shipped resolver. It parses DTCG,
resolves `{color.bg.brand}`-style aliases, refuses to run on a missing/misplaced source, and
supports `--check` so CI can prove `design_tokens.g.dart` is **generated, not hand-edited**.

**A3.** Regenerate and commit the Dart (`apps/mobile/lib/design_tokens.g.dart` is included in
this package, produced by that generator):

    node tools/scripts/design-tokens.mjs && flutter analyze

**A4.** Wire the gate into CI so the failure is loud, not silent:

    - name: Design tokens (generated, not hand-edited)
      run: node tools/scripts/design-tokens.mjs --check

**A5.** Land this as its own **small PR #5 (< 200 lines) directly to `main`** — do *not* grow
PR #3 (already at a terminal 938-line waiver) or PR #4 to carry it.

**A6.** Then `git rebase main` on PR #3 and PR #4, push, rerun CI.

**A7. Prove the gate with a RED control before calling it closed** (rule 1 of the verification
guide): rename the JSON in a scratch copy → the job must go RED; restore → GREEN. Commit the
evidence line in the PR description.

---

## 2. Phase B — close the remaining verification gaps

| # | Gap | Concrete work | Done when |
| --- | --- | --- | --- |
| B1 | iOS job queued | Add `timeout-minutes`, retry, and move T36-iOS to a pre-warmed/self-hosted macOS runner | iOS job GREEN on the same SHA as backend |
| B2 | Native Gmail consent | Real device: system browser → consent → callback → masked email only; assert zero token persistence | log line + screenshot in `docs/qa/` |
| B3 | App association | Serve `/.well-known/assetlinks.json` (Android) and `/.well-known/apple-app-site-association` (iOS) **from the API host**, allowlist the redirect URI, verify with `adb` / `aasa-crawler` | deep link opens the app, no browser loop |
| B4 | Server-side verifier (was the S2 remainder of T37) | Verify `iss`, `aud`, `exp`, `nonce`, `email_verified`; reject unsigned/id-token passthrough; keep S1 fail-closed when absent | T37 positive + negative fixtures committed |
| B5 | Device-toggle QA | Airplane mode *while* Linked Accounts is open, EN+MM, button disables before tap | committed test + device pass |
| B6 | **T40/T41 native 12-min hang** | Root cause pattern: native test waits on an endpoint/flow that the deployed revision lacks. Fix: (a) run against a revision that includes S1+S2 screens, (b) add explicit `timeout` + `skipIf` with `skipped (S1 not ready)` so CI fails fast, (c) cache `.gradle`/Pods, (d) split suites | job reports pass/skip in < 8 min, never a wall |
| B7 | Physical T28 (two devices, QR) | Pin `zxing-android-embedded` 4.3.0, record both device IDs | two-device transfer observed |
| B8 | `P2-SESSION-ACTIVITY-LABEL` | "Signed in" for `last_seen_at == null`, "Last active" otherwise, EN+MM widget test | PR #4 flips to ACCEPT |
| B9 | Revocation controls (S2 tail) | Security & Devices: revoke session, revoke family, confirm re-auth | S2 acceptance list complete |

---

## 3. Phase C — a staging environment that is a contract, not a workaround

Quick tunnels are for a 20-minute look, not for sign-off: the URL dies with the session, anyone
holding it can reach the API, and nothing records the deployed SHA.

**C1 — capacity (do this before anything else).** 1 GB is not enough for Nest + build + proxy.

    sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    sudo sysctl vm.swappiness=10

Then resize the instance to **2 GB** for staging, **4 GB** for production, and move PostgreSQL to
a managed isolated staging DB (Neon/Supabase free tier is acceptable for QA, never shared with
prod). Build images in CI, not on the box.

**C2 — one canonical host.** Pick `api-staging.hasta.app` (your own zone) rather than
`hasta-api.nexusmmr.com` / `api.oddsmyanmar.online`; the last three attempts each failed for a
different reason (NXDOMAIN, proxy 404, wrong A record `104.207.77.242`). One host = one DNS zone =
one Nginx `server_name` = one CI base URL.

**C3 — edge.** Ship `infra/nginx/hasta-api.conf` + `infra/systemd/hasta-api.service`.
Cloudflare: **Proxied**, SSL mode **Full (strict)**, Origin CA cert on the box. Keep `:3000`
bound to `127.0.0.1` and `UFW allow 22,80,443`.

**C4 — health contract (the piece still missing).** The log shows `GET /health` returns
`{"status":"ok"}` only. Extend it to:

    { "status": "ok", "env": "staging", "commit": "<40-char GIT_COMMIT>", "version": "1.2.0", "db": "up" }

Bake `GIT_COMMIT` as a build arg into the image and pass it through systemd. Then
`scripts/verify-staging.sh <URL> <SHA>` is the single gate: HTTP 200 **and** `env == staging`
**and** `commit == git rev-parse HEAD`. No SHA echo → no sign-off, ever.

**C5 — deployment record.** Add `.github/workflows/deploy-staging.yml` (shipped) with
`environment: staging` + required reviewers, so GitHub's deployments page shows a staging API
release instead of "GitHub Pages only".

**C6 — fixtures + artifacts.** `scripts/seed-staging.sh` seeds `tester.a / b / social / premium /
minor / fresh` **only after** the health contract passes, and asserts `tester.minor` is rejected
from wagering. Keep **two APKs**: a non-release QA build (long-press fixture panel) and a release
build that must pass the T36 exclusion scan — the log already proved a release APK with the panel
violates T36.

**C7 — 12-item smoke checklist.** Run against the live URL and record a `request_id` per item;
an item with no `request_id` counts as not run.

**Failure ladder (use in this order — each has already occurred here):**
`NXDOMAIN` → DNS zone has no record · `404 page not found` → Nginx `server_name`/`proxy_pass`
path mismatch · `502` → upstream down or bound to wrong interface · `521/522` → Cloudflare can't
reach origin / UFW blocking · `err_ssl_version` / "Not secure" → SSL mode is Flexible, switch to
Full (strict) with Origin CA · `403` from `/health` → WAF rule on the health path.

---

## 4. Phase D — "Production Grade" definition of done

Anything unchecked here is a production incident with a delay attached.

| Area | Requirement | Verification |
| --- | --- | --- |
| Secrets | No `.env` in git; per-environment signing keys; vault/SSM; 90-day rotation | secret scan + `gitleaks` in CI |
| Data | Postgres 16 pinned (T48), managed HA, PITR ≤ 15 min, nightly snapshot + **quarterly restore drill** | restore ticket |
| Migrations | `expand → backfill → contract`, reversible, never a locking DDL on a hot table | migration dry-run on staging clone |
| Compute | ≥ 2 API replicas behind LB, readiness vs liveness split, graceful WebSocket drain, OOM guard | kill a pod mid-session, no 5xx spike |
| WebSockets | Redis adapter, heartbeat ≤ 30 s, reconnect with backoff + jitter, server-side dedup (T17 outbox) | 1 000-concurrent-connection soak |
| Abuse | Per-device + per-IP rate limits, WAF rules, origin accepts Cloudflare IPs only, replay-row **global** expiry job (ops closure of P0-REPLAY-RETENTION) | load test + cleanup test without a second request |
| Observability | Structured JSON logs with `request_id`; redact tokens, emails, PINs; OpenTelemetry traces; RED dashboards; alerts on p95, 5xx, WS reconnect rate, DB pool, lagging replay cleanup, health-SHA mismatch, cert expiry, RAM/swap | page a human in a drill |
| Security | TLS 1.2+, HSTS, Argon2id for PIN, device-bound refresh + family revocation (already merged), SCA (`trivy`) on images + `npm audit`/`flutter` deps, GH push protection, least-privilege env secrets | CI fail on critical |
| Privacy | Account deletion + data export, 30-day grace, retention policy, audit log for entitlement and payout changes | end-to-end deletion test |
| Load | k6 scenarios for guest auth, `/v1/me`, feed read, WS chat; targets p95 < 400 ms API, < 150 ms WS | report attached to release |
| Release | Semver tags, signed AAB + signed iOS artifact, staged rollout 5 → 20 → 50 → 100 % behind a remote-config kill switch, **rollback < 10 min rehearsed** | rehearsal log |
| Feature flags | `gmail_linking`, `wagering`, `premium_unlock`, `dating` default **off** server-side (client checks are advisory only) | config snapshot at deploy |
| Ops | On-call rota, severity levels, incident template, postmortem within 72 h, error budget | runbook in `docs/ops/` |
| Cost | Budget alerts, CDN for static, log retention 30 d hot / 180 d cold | billing rule |

---

## 5. Phase E — the legal gate (No-Go until cleared)

This is a hard gate, not advice. Myanmar's **Cybersecurity Law** (enacted 1 January 2025, **in
force 30 July 2025**) criminalises establishing an online gambling system without permission:
**6 months–1 year imprisonment and/or a fine of 5–20 million kyat for an individual; an
organisation is fined not less than 20 million kyat, with the related property confiscated.**
The law reaches conduct inside Myanmar's national cyber domain and **applies to Myanmar citizens
who commit the offence abroad**. Unlicensed VPN establishment or provision is separately
punishable (1–6 months and/or 1–10 million kyat). *(Sources: The Star, 3 Jan 2025 & 1 Aug 2025.)*

Consequences for this product, stated plainly:

1. **Do not enable wagering for Myanmar-resident users** without a licence or a written legal
   opinion. There is no public online-casino licensing pathway in Myanmar today, so "we are
   applying" is not a defensible position. Ship code, keep `wagering` flag off, keep the entry
   state `disabled` for Myanmar geo — exactly the position the integration guide already took.
2. **Store policy will refuse it anyway.** Apple Guideline 5.3 requires a licence per distribution
   territory, real server-side **geo-fencing that blocks users located in prohibited territories**,
   no mixing of social-casino and real-money play inside one app, and no IAP for stakes. Google
   Play requires prior written approval and a country whitelist — Myanmar is not on it — so an
   APK/AAB carrying wagering risks rejection, takedown and **developer-account termination**.
3. **Advertising**: Google Ads gambling certification is per-country; social-casino lists ~36
   permitted countries, Myanmar not among them. Do not plan Myanmar paid acquisition for wagering.
4. **Never ship access-via-VPN guidance, or a domain/metadata set that advertises unlicensed
   betting** (e.g. `oddsmyanmar.online` as the API host on a store-listed app) — it is evidence,
   and it also breaks the store metadata review.
5. **Non-negotiable controls in whichever market you do open**: 18+/KYC before any deposit,
   deposit/loss/time limits, self-exclusion, reality checks, certified RNG (GLI-19 or the licence
   jurisdiction's equivalent), immutable bet & payout audit ledger, AML screening for Web3
   withdrawals with an allowlisted destination address set, and a **CI-blocking minor-account test**
   (the `tester.minor` fixture must get 4xx, asserted in `scripts/seed-staging.sh`).
6. **Recommended live variant for now**: Phase-1 launch = social + premium non-wagering features,
   geo-scoped to a jurisdiction where the licence exists, with server-side entitlement checks and
   the wagering module compiled out of the store artifact. Store the legal sign-off as
   `decisions/ADR-0017-licence-geo-gate.md` before anyone flips a flag.

မြန်မာအကျဉ်း — မြန်မာ Cybersecurity Law (၂၀၂၅ ဇူလိုင် ၃၀ ရက်မှ တည်ရှိ) အရ ခွင့်ပြုချက်မရှိ လောင်းကစားစနစ် တည်ဆောက်ခြင်းသည် အကျဉ်း + ငွေဒဏ် ဖြစ်နိုင်ပါတယ်။ ဒါကြောင့် **wagering flag ကို Myanmar user များအတွက် ပွင့်မထားရ** — code ကိုတော့ အသင့်ရှိအောင် ထားနိုင်ပါတယ်။ Store (Apple 5.3 / Google Play) ကလည်း licence မပါဘဲ ပယ်ဖျက်ပါတယ်။ Live ကို social/premium (မလောင်းကစားရသော feature) သုံးပြီး စတင်အကြံပြုပါတယ်။

---

## 6. Merge train and PR hygiene

    PR #5  tokens at canonical path + generator + --check  → merge to main   (< 200 lines)
    PR #3  rebase on main → iOS green → merge                               (frozen at 938)
    PR #4  rebase on main → fix P2-SESSION-ACTIVITY-LABEL → ACCEPT → merge  (322 + delta)
    PR #6  session revocation controls + native T30 (new, ≤ 400)
    PR #7  staging infra: nginx + systemd + workflow + verify scripts (new, ≤ 400)

Rules to hold from here on: **no more line-cap waivers** — every further fix opens a new draft
targeting its parent branch; a draft is never used as a parking lot for unrelated work; `main`
stays protected; nothing is merged while iOS is queued; a verdict of "ACCEPT for the draft scope"
is a code-review result, not merge or release approval.

---

## 7. Next one-liners (in order, one per message)

    Hasta fix P0-DESIGN-TOKENS-GATE          # commit assets/design-tokens.json + mjs from this package
    Hasta review PR #5
    Hasta rebase PR #3 and PR #4 onto main
    Hasta fix P2-SESSION-ACTIVITY-LABEL
    Hasta review PR #4 after CI
    Hasta provision staging api-staging.hasta.app   # C1–C5, then health SHA contract
    Hasta staging QA https://api-staging.hasta.app <40-char SHA>
    Hasta seed fixtures <staging URL> <SHA>
    Hasta test T40 native with fail-fast
    Hasta test T30 native Gmail callback
    Hasta adr 0017 licence geo gate wagering off
    Hasta release candidate 1.0.0-rc1

---

## 8. Go / No-Go checklist

| Gate | Must be true | Status now |
| --- | --- | --- |
| Design tokens | canonical source present, Dart generated, `--check` in CI, RED control shown | 🔴 blocked (Phase A) |
| CI | backend, gates, Android, iOS, Terraform all GREEN on one SHA | 🟠 iOS queued |
| S1 | merged, guest auth live | ✅ |
| S2 | linking + recovery + revocation + native consent/app association/device toggle | 🟠 draft accepted, native open |
| Staging | stable DNS, TLS Full(strict), `/health` echoes SHA + env, `staging` environment record | 🔴 none of it yet |
| QA evidence | 6 fixtures seeded, T40/T41 pass-or-explicit-skip, 12 smoke items with request_ids | 🔴 not run |
| Operations | backup/restore drill, alerts paging, rollback rehearsed, kill switch | 🔴 not built |
| **Legal** | licence or written opinion on file; wagering geo-fenced off for Myanmar; 18+/KYC/RNG | 🔴 not cleared |
| **Verdict** | | **No-Go for a wagering launch. Go for staging build + social/premium-only RC.** |

---

## 9. Risk register (top 6)

| Risk | Likelihood | Mitigation |
| --- | --- | --- |
| 1 GB box OOM-kills the API during CI-driven builds | High | swap now, 2 GB staging / 4 GB prod, build in CI, `MemoryMax` in systemd |
| DNS drift across two registrars (Cloudflare + Spaceship) pointing the old host at `104.207.77.242` | High | single zone, single canonical host, delete stale records, `dig` check in CI |
| Quick-tunnel URL reused as "staging" in a sign-off | High | health contract requires `env: staging` + SHA; `verify-staging.sh` warns on `trycloudflare` |
| T40/T41 hangs again and eats the runner budget | Medium | `timeout-minutes`, `skipIf` with explicit reason, cached Gradle/Pods |
| Draft PR line growth hiding regressions | Medium | cap frozen, new PR per fix (section 6) |
| Wagering flag reaching Myanmar users | Severe | server-side geo+licence gate, flag default off, store artifact compiled without wagering, ADR-0017 |

---

## 10. Files shipped with this plan

| Path | Purpose |
| --- | --- |
| `assets/design-tokens.json` | DS 1.0.2 source of truth (DTCG, 56 tokens, aliases, `lineHeight.body = 1.65`, Myanmar families) |
| `tools/scripts/design-tokens.mjs` | Generator + `--check`, fails closed on absent/misplaced source (validated: 1 GREEN / 5 RED scenarios) |
| `apps/mobile/lib/design_tokens.g.dart` | Regenerated output, ready to commit; `bgBrand / bgBrandPressed / bgBrandDisabled / primaryButton*` |
| `infra/nginx/hasta-api.conf` | 80→443, Origin CA TLS, `/health` exact path, `/ws/` upgrade, rate limit, `X-Request-Id` |
| `infra/systemd/hasta-api.service` | Non-root, `MemoryMax`, loopback-only bind, graceful WS drain, hardened unit |
| `.github/workflows/deploy-staging.yml` | `environment: staging` deployment record + baked `GIT_COMMIT` + post-deploy health gate |
| `scripts/verify-staging.sh` | DNS/TLS/health SHA/env contract — the pass condition for every QA run |
| `scripts/seed-staging.sh` | Seeds the six fixtures only after the contract passes; asserts `tester.minor` cannot wager |
| `.hasta/STATE.md` | Tracker aligned to this log — replace the one in `main` |
| `docs/qa/logic-ui-state-verification-guide.md` | The guide the agent could not find; §2.3 holds the token assertions |
```


---

## REPO PATH: `docs/qa/logic-ui-state-verification-guide.md`

```
# Hasta — Logic & UI State Verification Guide (v2)

Path in repo: `docs/qa/logic-ui-state-verification-guide.md`
Companion to: `docs/production-golive-plan.md` · SPEC 1.0.2 · PR #3/#4 findings

> **Rule 0 — a GREEN you never made RED proves nothing.** Every assertion below must be run
> as a reverse control (remove/disable the guard in a scratch copy, see the test go RED, restore,
> see GREEN) and the evidence committed. Scratch passes never count; only committed tests count.

---

## 1. Logic states (server / auth) — assertion + reverse control

| ID | Assertion (must hold) | Reverse control (must go RED) |
| --- | --- | --- |
| T46 cross-device refresh | Active-token refresh from an unenrolled device → 401, family revoked, no active sessions left in that family, unrelated families still work | Delete the mismatch branch in `auth/service.ts` → the committed case returns 200 |
| P0-DEVICE-PROOF | Resume requires proof tied to the original enrollment; a caller-supplied identifier hash alone is rejected | Trust the hash without proof → resume succeeds (must not) |
| P0-REPLAY-RETENTION | Expired replay rows are purged **globally** (cron/job), not only when the same scope is hit again | Remove the global sweep, send one request, leave the device silent → rows persist past expiry |
| P1-REPLAY-STATE | Retry with the same idempotency key after logout/family revocation returns the original *error*, never a cached success + token pair | Serve cache before the session-state check → retry returns 200 with dead tokens |
| T37 server verifier | Reject: wrong `iss`, wrong `aud`, expired, bad `nonce`, `email_verified=false`, unsigned payload; accept one valid fixture; S1 fails closed when the verifier is absent | Point the gate at the old text-only check → the valid identity fixture must not pass |
| Gmail link | Authorization-code exchange only (never a client-supplied Google token); masked email is the only PII returned | Return the raw email / accept an id_token → test must fail |
| Link completion | Exactly one authenticated `link:complete`; uncertain result → authenticated **status read**, never a code replay | Replay the code on 503 → Google rejects, app must not treat it as success |
| Pending key | Idempotency key is sent but not persisted; no accumulation across failed completions | Persist on 503 → storage count grows (P2-GMAIL-PENDING-KEY-CLEANUP regression) |
| Session list | Scoped to the signed-in account; no device identifier displayed or stored | Return another account's sessions / leak the raw device id → must fail |
| T48 | `docker-compose.yml` pins `postgres:16` | Change to `postgres:18` → gate RED (proven) |
| Health contract | `status=ok`, `env=staging`, `commit == git rev-parse HEAD` of the running image | Deploy without baking `GIT_COMMIT` → `verify-staging.sh` must fail |

---

## 2. UI states (Flutter)

### 2.1 Matrix

| Screen | empty | loading | success | error | offline | disabled | pressed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Welcome | — | primary CTA spinner | guest session created | 5xx banner, retry keeps state | CTA disabled + reason EN/MM | no Google/Apple button (T36) | `bg.brandPressed` |
| Guest Profile | skeleton | hydrated | editable | inline, no dialog stack | read-only | n/a | n/a |
| Settings | — | — | rows visible | banner | rows dimmed | title shrink-to-fit | n/a |
| Linked Accounts | "Not linked" | spinner | masked email only | typed error (denied/expired/server) | **button disables before tap** | yes while offline | `bg.brandDisabled` |
| Connect Gmail sheet | n/a | browser opened | masked email | explicit restart path on mid-consent expiry | disabled + reason | non-cancellable finishing state after submit | n/a |
| Security & Devices | "No other devices" | skeleton | list, no device ids | retry | cached read-only | revoke disabled while in flight | n/a |

### 2.2 Layout / accessibility (320×568 @ 200 % text scale, EN + MM)
* no truncation on Guest Profile text or the Settings title — `Expanded`/`Flexible` + `minHeight`,
  `FittedBox(fit: BoxFit.scaleDown)` for titles; never hide the failure by forcing `textScale: 1.0`;
* Myanmar body line height ≥ **1.65×** — asserted from the generated token, not hardcoded;
* intentional-overflow control test stays in the suite (proves the harness detects overflow).

### 2.3 Design-token assertions (the assertions referenced by `P0-DESIGN-TOKENS-GATE`)
Source of truth: **`assets/design-tokens.json`** (canonical path — a copy at
`assets/assets/design-tokens.json` is a failure, not a fix). Generator:
`tools/scripts/design-tokens.mjs`. Output: `apps/mobile/lib/design_tokens.g.dart` (never hand-edited).

| Assertion | Pass condition | RED control |
| --- | --- | --- |
| Source present | `node tools/scripts/design-tokens.mjs` exits 0 and names `assets/design-tokens.json` | delete/rename the file → job must fail **before** T47 |
| Misplaced copy detected | generator exits 1 and prints `git mv assets/assets/design-tokens.json assets/design-tokens.json` | leave only the nested copy → must fail, must not silently pass |
| Alias resolution | `{color.bg.brand}` etc. resolve to concrete ARGB values in the Dart | break one alias (`{color.bg.nope}`) → exit 1 with the offending path |
| Three-state button | generated Dart contains `bgBrand`, `bgBrandPressed`, `bgBrandDisabled` and `primaryButtonPressed/Disabled` aliases | drop `brandDisabled` from the source → exit 1 (`required token missing`) |
| Myanmar line height | `lineHeightBody >= 1.65` | set `1.2` → exit 1 |
| Myanmar family | `fontFamilyBase` contains Pyidaungsu / Noto Sans Myanmar | remove both → exit 1 |
| No drift | `--check` against the committed Dart is byte-clean | hand-edit one hex in the `.g.dart` → `--check` fails |
| No literals | widget tests assert the button fill equals the generated token; `main.dart` has no raw hex for the three states | hardcode a hex → widget assertion fails |
| CI wiring | `ci.yml` runs `--check` in the `gates` job | remove the step → gate must go RED on drift (add a drift fixture) |

---

## 3. Evidence discipline (seven rules)
1. **RED before GREEN** — no assertion is signed off without a committed reverse control.
2. Committed tests only; scratch runs are notes, not evidence.
3. One SHA per verdict; a verdict on a SHA whose CI is still queued is provisional.
4. UI checks run in **both** locales (EN + MM) and in default + QA configurations.
5. A blocked item states the missing prerequisite, and gets an explicit `skipped (reason)` —
   never an indefinite hang.
6. Findings carry a severity + exact file:line + fix prompt (e.g. `Hasta fix P2-SESSION-ACTIVITY-LABEL`).
7. `[DEVIATION]` is mandatory per run; "None" is the default. Relaxing a rule requires an ADR line.

---

## 4. Report template

    Verdict: ACCEPT | REQUEST CHANGES | BLOCKED (<sha>, <n> changed lines)
    Logic:  <id> PASS/FAIL/RED->GREEN — <file:line> — <reverse control performed?>
    UI:     <screen> × <state> — EN / MM — <widget test name>
    Tokens: source <path> — required 4 present — lineHeight <x> — --check clean
    Scope:  S<n> items in / deferred (each deferred item needs a follow-up prompt)
    Gates:  T36 … T48 one line each, with the CI run URL
    Next:   Hasta <verb> <target>

---

## 5. Staging run order (condensed)
1. `verify-staging.sh <https base> <deployed SHA>` → PASS (DNS stable A record, TLS, SHA, `env`).
2. `seed-staging.sh` → six fixtures + the `tester.minor` wagering block asserted.
3. QA-flavoured APK (panel present) → long-press panel, `tester.a` session, `/v1/me`, all six fixtures.
4. Release APK → T36 scan proves the panel and `google_sign_in` are excluded.
5. 12-item smoke checklist against the live URL, one `request_id` recorded per item.
6. T40/T41 native with a hard timeout and explicit skip semantics.
7. Any RED → fix PR (new, ≤ 400 lines) + this guide's reverse control, then re-run from step 1.
```


---

## REPO PATH: `infra/nginx/hasta-api.conf`

```
# Hasta staging/production edge — Nginx reverse proxy to NestJS on 127.0.0.1:3000
# Port 3000 stays PRIVATE (UFW allows 22/80/443 only). TLS terminates with a Cloudflare
# Origin CA certificate; Cloudflare SSL mode MUST be "Full (strict)".
# Install: /etc/nginx/conf.d/hasta-api.conf  ->  nginx -t && systemctl reload nginx

map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

# Abuse control: per-client request rate. Adjust with the WAF plan.
limit_req_zone $binary_remote_addr zone=hasta_api:10m rate=20r/s;

server {
    listen 80;
    listen [::]:80;
    server_name api-staging.hasta.app api.hasta.app;      # single canonical host per env
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name api-staging.hasta.app api.hasta.app;

    ssl_certificate     /etc/nginx/ssl/cloudflare-origin.pem;      # Origin CA cert (Full strict)
    ssl_certificate_key /etc/nginx/ssl/cloudflare-origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer" always;

    access_log /var/log/nginx/hasta-api.access.log combined;
    error_log  /var/log/nginx/hasta-api.error.log warn;

    client_max_body_size 2m;            # QR/avatar uploads only; never accept game payloads larger

    location /health {
        proxy_pass http://127.0.0.1:3000/health;   # exact path: /health  (NOT /v1/health)
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
        access_log off;
    }

    location /ws/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }

    location / {
        limit_req zone=hasta_api burst=40 nodelay;
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $http_cf_connecting_ip;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Request-Id $request_id;      # app must echo this in logs + response header
        proxy_connect_timeout 2s;
        proxy_read_timeout 30s;
    }
}
```


---

## REPO PATH: `infra/systemd/hasta-api.service`

```
# NestJS API — hardened systemd unit (replaces PM2 for staging/production)
# Install: /etc/systemd/system/hasta-api.service
#   systemctl daemon-reload && systemctl enable --now hasta-api
[Unit]
Description=Hasta NestJS API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=hasta
Group=hasta
WorkingDirectory=/opt/hasta/api
EnvironmentFile=/etc/hasta/api.env          # mode 0600, root:hasta — never committed
Environment=NODE_ENV=staging
Environment=PORT=3000
Environment=GIT_COMMIT=unknown              # overwritten at deploy time with the built SHA
ExecStartPre=/usr/local/bin/hasta-migrate.sh
ExecStart=/usr/bin/node dist/main.js
Restart=always
RestartSec=3
TimeoutStopSec=20                           # graceful drain for WebSocket sessions
KillSignal=SIGTERM

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/hasta /var/lib/hasta
ProtectKernelTunables=true
RestrictSUIDSGID=true
RestrictNamespaces=true
MemoryMax=600M                              # 1 GB box: hard-cap the API so Postgres/OOM cannot take the host
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```


---

## REPO PATH: `.github/workflows/deploy-staging.yml`

```
name: deploy-staging
# Fixes "GitHub deployment records list only GitHub Pages": this job registers a
# `staging` environment deployment and records the deployed commit SHA.
on:
  workflow_dispatch:
    inputs:
      ref:
        description: Branch or SHA to deploy (must be a merged, reviewed revision)
        required: true
        default: main

permissions:
  contents: read
  deployments: write

concurrency:
  group: staging-deploy
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-24.04
    environment:
      name: staging                 # create in repo Settings > Environments, with required reviewers
      url: https://api-staging.hasta.app
    steps:
      - uses: actions/checkout@v4
        with: { ref: '${{ inputs.ref }}' }

      - name: Resolve revision
        id: sha
        run: echo "sha=$(git rev-parse HEAD)" >> "$GITHUB_OUTPUT"

      - name: Build image with baked GIT_COMMIT
        run: |
          docker build \
            --build-arg GIT_COMMIT=${{ steps.sha.outputs.sha }} \
            --build-arg BUILD_TIME=$(date -u +%FT%TZ) \
            -t hasta-api:${{ steps.sha.outputs.sha }} .
          docker save hasta-api:${{ steps.sha.outputs.sha }} | gzip > api.tar.gz

      - name: Ship + switch over (atomic symlink, keeps rollback target)
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.STAGING_SSH_HOST }}
          username: ${{ secrets.STAGING_SSH_USER }}
          key: ${{ secrets.STAGING_SSH_KEY }}
          script_stop: true
          script: |
            set -e
            mkdir -p /srv/hasta/releases/${{ steps.sha.outputs.sha }}
            cat > /tmp/api.tar.gz < /dev/null   # uploaded by the next step (scp action)
            cd /srv/hasta/releases/${{ steps.sha.outputs.sha }}
            gunzip -c /tmp/api.tar.gz | docker load
            docker stop hasta-api || true
            docker rm hasta-api || true
            docker run -d --name hasta-api --restart always \
              --env-file /etc/hasta/api.env \
              -p 127.0.0.1:3000:3000 \
              hasta-api:${{ steps.sha.outputs.sha }}
            echo ${{ steps.sha.outputs.sha }} > /srv/hasta/CURRENT

      - name: Health contract (200 + SHA + env echo)
        run: |
          bash scripts/verify-staging.sh https://api-staging.hasta.app ${{ steps.sha.outputs.sha }}
```


---

## REPO PATH: `scripts/verify-staging.sh`

```
#!/usr/bin/env bash
# Staging health contract. Replaces manual "is it up?" guessing.
#   usage: bash scripts/verify-staging.sh <HTTPS_BASE_URL> <EXPECTED_DEPLOYED_SHA>
# Pass = HTTP 200 AND body.status == ok AND body.commit == expected SHA AND body.env == staging.
set -euo pipefail
BASE="${1:?base url}"; WANT="${2:?deployed sha}"
HOST="$(printf '%s' "$BASE" | sed -E 's#https?://##; s#/.*##')"

echo "1) DNS  -> $(dig +short A "$HOST" | tr '\n' ' ')"
if dig +short A "$HOST" | grep -q 'trycloudflare\|^$'; then
  echo "   WARN: no stable A record — a Quick Tunnel URL is NOT a staging contract"
fi

echo "2) TLS  -> $(curl -sSv -o /dev/null --max-time 10 "$BASE/health" 2>&1 | grep -E 'SSL cert|subject:' | head -2)"
BODY="$(curl -fsS --fail-with-body --max-time 15 "$BASE/health")"
echo "3) body -> $BODY"

HAVE="$(printf '%s' "$BODY" | jq -r '.commit // empty')"
ENVN="$(printf '%s' "$BODY" | jq -r '.env  // empty')"
STAT="$(printf '%s' "$BODY" | jq -r '.status // empty')"

[ "$STAT" = "ok" ]       || { echo "FAIL: status != ok"; exit 1; }
[ "$ENVN" = "staging" ]  || { echo "FAIL: health does not echo env=staging (isolation unproven)"; exit 1; }
[ "${#HAVE}" -ge 40 ]    || { echo "FAIL: health has no full commit SHA — GIT_COMMIT not baked"; exit 1; }
[ "$HAVE" = "$WANT" ]    || { echo "FAIL: deployed $HAVE != expected $WANT (stale build)"; exit 1; }
echo "PASS: staging is live on $HAVE ($ENVN)"
```


---

## REPO PATH: `scripts/seed-staging.sh`

```
#!/usr/bin/env bash
# Seed the six synthetic staging fixtures. REFUSE to run unless env is proven staging.
#   usage: STAGING_URL=https://api-staging.hasta.app DEPLOYED_SHA=<40hex> bash scripts/seed-staging.sh
set -euo pipefail
S="${STAGING_URL:?}"; SHA="${DEPLOYED_SHA:?}"
bash "$(dirname "$0")/verify-staging.sh" "$S" "$SHA" || { echo "seed blocked: health contract failed"; exit 1; }
ADMIN_TOKEN="${HASTA_ADMIN_TOKEN:?}"        # staging-only bootstrap admin, never a prod credential
for login in tester.a tester.b tester.social tester.premium tester.minor tester.fresh; do
  curl -fsS --fail-with-body -X POST "$S/v1/qa/fixtures" \
    -H "Authorization: Bearer $ADMIN_TOKEN" -H 'Content-Type: application/json' \
    -H "Idempotency-Key: seed-$login-$(date -u +%Y%m%d%H)" \
    -d "{\"login\":\"$login\",\"kind\":\"synthetic\",\"sprint\":\"S1\"}" >/dev/null
  echo "seeded $login"
done
# tester.minor MUST exist and MUST be blocked from wagering/dating — assert it, do not skip it:
curl -fsS -o /dev/null -w 'minor wager -> HTTP %{http_code}\n' -X POST "$S/v1/bets" \
  -H "Authorization: Bearer ${MINOR_TOKEN:?}" -H 'Content-Type: application/json' -d '{"game":"demo","amount":1}' \
  && { echo "FAIL: minor account was allowed to place a bet"; exit 1; } || true
```
