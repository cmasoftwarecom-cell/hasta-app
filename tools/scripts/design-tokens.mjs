import { readFileSync, writeFileSync } from 'node:fs';

const root = new URL('../../', import.meta.url);
const source = JSON.parse(readFileSync(new URL('assets/design-tokens.json', root), 'utf8'));
const target = new URL('apps/mobile/lib/core/design/tokens.dart', root);
const { color } = source.tier2_semantic;
const argb = (hex, opacity) => {
  if (!/^#[\da-f]{6}([\da-f]{2})?$/i.test(hex)) throw new Error(`Invalid token: ${hex}`);
  const alpha = hex.slice(7) || 'FF';
  const effective = opacity == null ? alpha : Math.round(parseInt(alpha, 16) * opacity)
    .toString(16).padStart(2, '0').toUpperCase();
  return `Color(0x${effective}${hex.slice(1, 7)})`;
};
const palette = (theme) => [
  `  static const ${theme} = <String, Color>{`,
  ...Object.entries(color).map(([name, pair]) =>
    `    '${name}': ${argb(pair[theme] ?? pair.dark, theme !== 'light' ? pair.opacity : null)},`),
  '  };',
];
const { scale, myanmarRules } = source.typography;
const output = [
  '// GENERATED from assets/design-tokens.json. Do not edit.',
  "import 'package:flutter/painting.dart';",
  '',
  'abstract final class HastaTokens {',
  ...['light', 'dark', 'amoled'].flatMap(palette),
  '',
  `  static const spacing = <double>[${source.spacing.scale.join(', ')}];`,
  `  static const myanmarLineHeight = ${myanmarRules.minLineHeightRatio};`,
  '  static const myanmarFontFamily = \'Noto Sans Myanmar\';',
  '  static const myanmarType = <String, TextStyle>{',
  ...Object.entries(scale).filter(([, type]) => type.weight).flatMap(([name, type]) => [
    `    '${name}': TextStyle(`,
    '      fontFamily: myanmarFontFamily,',
    `      fontSize: ${type.size},`,
    `      fontWeight: FontWeight.w${Math.min(type.weight, myanmarRules.boldMaxWeight)},`,
    `      letterSpacing: ${type.letterSpacing},`,
    `      height: ${Math.max(type.lineHeight / type.size, myanmarRules.minLineHeightRatio)},`,
    '    ),',
  ]),
  '  };',
  '}',
  '',
].join('\n');
if (process.argv.includes('--check')) {
  if (readFileSync(target, 'utf8') !== output) throw new Error('Regenerate tokens.dart');
} else {
  writeFileSync(target, output);
}
