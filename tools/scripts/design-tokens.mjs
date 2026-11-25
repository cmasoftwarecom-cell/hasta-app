import { existsSync, readFileSync, writeFileSync } from 'node:fs';

const root = new URL('../../', import.meta.url);
const sourcePath = 'assets/design-tokens.json';
const legacyPath = 'assets/assets/design-tokens.json';
const target = 'apps/mobile/lib/design_tokens.g.dart';
const readJson = (path) => JSON.parse(readFileSync(new URL(path, root), 'utf8'));
if (!existsSync(new URL(sourcePath, root))) {
  console.error(`Missing required source: ${sourcePath}`);
  if (existsSync(new URL(legacyPath, root))) {
    console.error(`Canonical path: git mv ${legacyPath} ${sourcePath} (use the DTCG source, not a legacy-format replacement)`);
  }
  process.exit(1);
}
const source = readJson(sourcePath);
const legacy = readJson(legacyPath);
const find = (path) => path.split('.').reduce(
  (node, key) => node && Object.hasOwn(node, key) ? node[key] : undefined, source);
function resolveToken(path, type, chain = []) {
  if (chain.includes(path)) throw new Error(`Circular token alias: ${[...chain, path].join(' → ')}`);
  const token = find(path);
  if (!token || !Object.hasOwn(token, '$value')) {
    throw new Error(`required token missing: ${path}${chain.length ? ` (alias from ${chain.join(' → ')})` : ''}`);
  }
  if (token.$type !== type) throw new Error(`${path}: expected $type ${type}`);
  const value = token.$value;
  const reference = typeof value === 'string' && /^\{([^{}]+)\}$/.exec(value);
  return reference ? resolveToken(reference[1], type, [...chain, path]) : { path, value };
}

const brand = {
  bgBrand: 'bg.brand',
  bgBrandPressed: 'bg.brandPressed',
  bgBrandDisabled: 'bg.brandDisabled',
};
const button = {
  primaryButton: ['background', 'bgBrand'],
  primaryButtonPressed: ['backgroundPressed', 'bgBrandPressed'],
  primaryButtonDisabled: ['backgroundDisabled', 'bgBrandDisabled'],
};
for (const name of Object.values(brand)) resolveToken(`color.${name}`, 'color');
for (const [suffix, name] of Object.values(button)) {
  const from = `component.button.primary.${suffix}`;
  const expected = `color.${brand[name]}`;
  if (resolveToken(from, 'color').path !== resolveToken(expected, 'color').path) {
    throw new Error(`${from}: expected an alias to ${expected}`);
  }
}
const lineHeight = resolveToken('typography.lineHeight.body', 'number').value;
if (!Number.isFinite(lineHeight) || lineHeight < 1.65) {
  throw new Error('typography.lineHeight.body: expected a number ≥ 1.65');
}
const fontFamily = resolveToken('typography.fontFamily.base', 'family').value;
if (!Array.isArray(fontFamily) || !fontFamily.every((name) => typeof name === 'string') ||
    !fontFamily.some((name) => ['Pyidaungsu', 'Noto Sans Myanmar'].includes(name))) {
  throw new Error('typography.fontFamily.base: expected Pyidaungsu or Noto Sans Myanmar');
}
const dartString = (value) => JSON.stringify(value).replaceAll('$', '\\$');
const argb = (hex, opacity) => {
  if (typeof hex !== 'string' || !/^#[\da-f]{6}([\da-f]{2})?$/i.test(hex)) {
    throw new Error(`Invalid color token: ${hex}`);
  }
  const alpha = hex.slice(7) || 'FF';
  const effective = opacity == null ? alpha : Math.round(parseInt(alpha, 16) * opacity)
    .toString(16).padStart(2, '0').toUpperCase();
  return `Color(0x${effective}${hex.slice(1, 7)})`;
};
function colors(group, prefix = 'color') {
  return Object.entries(group).filter(([key]) => !key.startsWith('$')).flatMap(([key, value]) => {
    const path = `${prefix}.${key}`;
    return Object.hasOwn(value, '$value') ? [[path.slice(6), argb(resolveToken(path, 'color').value)]]
      : colors(value, path);
  });
}
const darkColors = Object.fromEntries(colors(source.color));
const brandNames = Object.fromEntries(Object.entries(brand).map(([key, name]) => [name, key]));
const palette = (theme) => {
  // The DTCG source supplies one dark palette, without light or AMOLED variants.
  // Keep existing theme-specific values for non-brand tokens otherwise.
  const entries = Object.fromEntries(Object.entries(legacy.tier2_semantic.color).map(([name, pair]) =>
    [name, argb(pair[theme] ?? pair.dark, theme !== 'light' ? pair.opacity : null)]));
  if (theme === 'dark') Object.assign(entries, darkColors);
  return [
    `  static const ${theme} = <String, Color>{`,
    ...Object.entries({ ...entries, ...brandNames }).map(([name, value]) => `    '${name}': ${value},`),
    '  };',
  ];
};
const { scale, myanmarRules } = legacy.typography;
const output = [
  '// GENERATED from assets/design-tokens.json. Do not edit.',
  '// Legacy theme variants, spacing and text roles are compatibility data.',
  "import 'package:flutter/painting.dart';",
  '',
  'abstract final class HastaTokens {',
  ...Object.entries(brand).map(([name, key]) => `  static const ${name} = ${darkColors[key]};`),
  ...Object.entries(button).map(([name, [, target]]) => `  static const ${name} = ${target};`),
  `  static const lineHeightBody = ${Number.isInteger(lineHeight) ? lineHeight.toFixed(1) : lineHeight};`,
  `  static const fontFamilyBase = <String>[${fontFamily.map(dartString).join(', ')}];`,
  '',
  ...['light', 'dark', 'amoled'].flatMap(palette),
  '',
  `  static const spacing = <double>[${legacy.spacing.scale.join(', ')}];`,
  '  static const myanmarLineHeight = lineHeightBody;',
  '  static const myanmarFontFamily = \'Noto Sans Myanmar\';',
  '  static const myanmarType = <String, TextStyle>{',
  ...Object.entries(scale).filter(([, type]) => type.weight).flatMap(([name, type]) => [
    `    '${name}': TextStyle(`,
    '      fontFamily: myanmarFontFamily,',
    `      fontSize: ${type.size},`,
    `      fontWeight: FontWeight.w${Math.min(type.weight, myanmarRules.boldMaxWeight)},`,
    `      letterSpacing: ${type.letterSpacing},`,
    `      height: ${Math.max(type.lineHeight / type.size, lineHeight)},`,
    '    ),',
  ]),
  '  };',
  '}',
  '',
].join('\n');
const url = new URL(target, root);
if (process.argv.includes('--check')) {
  if (!existsSync(url) || readFileSync(url, 'utf8') !== output) {
    throw new Error(`Regenerate ${target} from ${sourcePath}`);
  }
} else {
  writeFileSync(url, output);
}
console.log(`${sourcePath} → ${target}`);
