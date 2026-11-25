import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const contract = 'docs/api/openapi.json';
const pinnedBootstrap = new URL('../../docs/api/baselines/s1-bootstrap.json', import.meta.url);
const pinnedDigest = '81987f3070920db5e274de6e957e35102889bf388db0f1c1a422bb33f1ce0922';
const stableTag = /^v(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$/;

export function selectBaseline({ cwd = process.cwd(), base, bootstrapPath = pinnedBootstrap,
  bootstrapDigest = pinnedDigest } = {}) {
  assert.match(base ?? '', /^[a-f0-9]{40}$/, 'T47: provide the trusted base commit SHA');
  const git = (...args) => execFileSync('git', args, { cwd, stdio: ['ignore', 'pipe', 'pipe'] });
  try {
    git('rev-parse', '--verify', `${base}^{commit}`);
  } catch (cause) {
    throw new Error('T47: trusted base commit is unavailable; fetch complete history', { cause });
  }

  const tag = git('tag', '--merged', base, '--sort=-version:refname')
    .toString().split(/\r?\n/).find((name) => stableTag.test(name));
  if (tag) {
    const label = `refs/tags/${tag}`;
    try {
      return { label, document: git('show', `${label}:${contract}`) };
    } catch (cause) {
      throw new Error(`T47: ${label} is missing ${contract}`, { cause });
    }
  }

  const document = readFileSync(bootstrapPath);
  assert.equal(createHash('sha256').update(document).digest('hex'), bootstrapDigest,
    'T47: pinned bootstrap digest mismatch; do not modify the comparison baseline');
  return { label: 'pinned S1 bootstrap', document };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const { label, document } = selectBaseline({ base: process.argv[2] });
    process.stderr.write(`T47 baseline: ${label}\n`);
    process.stdout.write(document);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
