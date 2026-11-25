import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gunzipSync } from 'node:zlib';
import { test } from 'node:test';

const repo = new URL('../../', import.meta.url);
const workflow = readFileSync(new URL('.github/workflows/deploy-staging.yml', repo), 'utf8');
const script = fileURLToPath(new URL('tools/scripts/deploy-staging.sh', repo));
const sha = 'a'.repeat(40);
const previous = 'b'.repeat(40);
const url = 'https://api-staging.hasta.app';

test('staging deploy wires the server image build to the protected manual job', () => {
  assert.match(workflow, /workflow_dispatch:/);
  assert.doesNotMatch(workflow, /(?:^|\n)  (?:push|pull_request):/);
  assert.match(workflow, /if: github\.ref == 'refs\/heads\/main'/);
  assert.match(workflow, /environment:\s*\n\s+name: staging/);
  assert.match(workflow, /git -C deployment-source merge-base --is-ancestor "\$sha" origin\/main/);
  assert.match(workflow, /deploy-staging\.sh build "\$DEPLOY_SHA" deployment-source "\$RUNNER_TEMP\/api\.tar\.gz"/);
});

test('staging deploy sends the built archive before running the tracked verifier', () => {
  assert.ok(workflow.includes(`deploy-staging.sh ship "$DEPLOY_SHA" "$RUNNER_TEMP/api.tar.gz" ${url}`));
  assert.doesNotMatch(workflow, /api\.tar\.gz\s*<\s*\/dev\/null/);
});

function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), 'hasta-deploy-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const archive = join(dir, 'api.tar.gz');
  for (const [name, body] of Object.entries({
    docker: `
printf '%s\\n' "$*" >> "$RUNNER_TEMP/docker.log"
state="$RUNNER_TEMP/container-state"
case "$1" in
  run)
    if [[ "$2" == --rm ]]; then printf '%s' "$BAKED"; exit; fi
    printf '%s' candidate > "$state/hasta-api"
    [[ \${FAIL_RUN:-0} == 0 ]]
    ;;
  save) printf '%s' 'synthetic docker archive' ;;
  load)
    [[ $(cat) == 'synthetic docker archive' ]]
    [[ \${FAIL_LOAD:-0} == 0 ]]
    ;;
  container)
    case "\${*: -1}" in
      name=*) name=\${*: -1}; name=\${name#*=^/}; name=\${name%\\$}
              if [[ -f "$state/$name" ]]; then cat "$state/$name"; fi ;;
      label=*) if grep -qx candidate "$state/hasta-api" 2>/dev/null; then echo candidate; fi ;;
    esac ;;
  inspect) echo true ;;
  rename) mv "$state/$(find "$state" -type f -exec grep -lx "$2" {} + | xargs -r basename)" "$state/$3" ;;
  rm) if [[ "$2" == -f ]]; then shift; fi
      find "$state" -type f -exec grep -lx "$2" {} + | xargs -r rm -- ;;
esac`,
    ssh: `
printf '%s\\n' "$*" >> "$RUNNER_TEMP/ssh-request"
input="$(mktemp "$RUNNER_TEMP/ssh-input.XXXXXX")"
cat > "$input"
if [[ -s $input ]]; then cp "$input" "$RUNNER_TEMP/received"; fi
command=\${!#}
command=\${command//\\/srv\\/hasta/$RUNNER_TEMP\\/remote}
command=\${command//\\/etc\\/hasta\\/api.env/$RUNNER_TEMP\\/api.env}
sh -c "$command" < "$input"
`,
    dig: 'echo 192.0.2.10',
    curl: `
if [[ "$1" == -sSv ]]; then echo '* SSL certificate verify ok.' >&2; exit; fi
cp "$RUNNER_TEMP/remote/CURRENT" "$RUNNER_TEMP/current-during-health"
[[ \${FAIL_HEALTH:-0} == 0 ]] || exit 22
printf '{"status":"ok","env":"staging","commit":"%s"}\\n' "$BAKED"`,
  })) writeFileSync(join(dir, name), `#!/usr/bin/env bash\nset -eu\n${body}\n`, { mode: 0o700 });
  writeFileSync(join(dir, 'api.env'), 'HASTA_ENV=staging\n');
  for (const sub of ['container-state', 'remote']) mkdirSync(join(dir, sub));
  writeFileSync(join(dir, 'container-state/hasta-api'), 'old-container');
  writeFileSync(join(dir, 'remote/CURRENT'), `${previous}\n`);
  const run = (args, overrides = {}) => spawnSync('bash', [script, ...args], {
    encoding: 'utf8',
    env: {
      PATH: `${dir}:${process.env.PATH}`, RUNNER_TEMP: dir, BAKED: sha,
      STAGING_SSH_HOST: 'isolated.invalid', STAGING_SSH_USER: 'fixture',
      STAGING_SSH_KEY: 'fixture-key', STAGING_SSH_KNOWN_HOSTS: 'fixture-host-key', ...overrides,
    },
  });
  return { dir, archive, run };
}

test('staging deploy builds the selected SHA and transfers the same nonempty archive', (t) => {
  const { dir, archive, run } = fixture(t);
  const build = run(['build', sha, 'deployment-source', archive]);
  assert.equal(build.status, 0, build.stderr);
  assert.deepEqual(readFileSync(join(dir, 'docker.log'), 'utf8').trim().split('\n'), [
    `build --build-arg GIT_COMMIT=${sha} --tag hasta-api:${sha} deployment-source/apps/server`,
    `run --rm --entrypoint cat hasta-api:${sha} /app/dist/build-commit`,
    `save hasta-api:${sha}`,
  ]);
  const ship = run(['ship', sha, archive, url]);
  assert.equal(ship.status, 0, ship.stderr);
  assert.deepEqual(readFileSync(join(dir, 'received')), readFileSync(archive));
  assert.equal(gunzipSync(readFileSync(archive)).toString(), 'synthetic docker archive');
  assert.match(readFileSync(join(dir, 'ssh-request'), 'utf8'), /StrictHostKeyChecking=yes/);
  assert.equal(readFileSync(join(dir, 'current-during-health'), 'utf8'), `${previous}\n`);
  assert.equal(readFileSync(join(dir, 'remote', 'CURRENT'), 'utf8'), `${sha}\n`);
  const calls = readFileSync(join(dir, 'docker.log'), 'utf8');
  assert.match(calls, /load\n[\s\S]*rename old-container [^\n]+\nstop old-container\nrun -d --pull=never/);
  assert.match(calls, /^rm old-container$/m);
});

test('staging deploy stops before shipping if SHA metadata or archive is missing', (t) => {
  const { dir, archive, run } = fixture(t);
  const build = run(['build', sha, 'deployment-source', archive], { BAKED: '' });
  assert.notEqual(build.status, 0);
  assert.match(build.stderr, /baked commit SHA/);
  assert.doesNotMatch(readFileSync(join(dir, 'docker.log'), 'utf8'), /^save /m);
  writeFileSync(archive, '');
  assert.notEqual(run(['ship', sha, archive, url]).status, 0);
  assert.throws(() => readFileSync(join(dir, 'ssh-request')), { code: 'ENOENT' });
});

test('staging deploy leaves the current container untouched if the remote docker load fails', (t) => {
  const { dir, archive, run } = fixture(t);
  assert.equal(run(['build', sha, 'deployment-source', archive]).status, 0);
  assert.notEqual(run(['ship', sha, archive, url], { FAIL_LOAD: '1' }).status, 0);
  const calls = readFileSync(join(dir, 'docker.log'), 'utf8');
  assert.match(calls, /^load$/m);
  assert.doesNotMatch(calls, /^(?:stop|rm|run -d) /m);
  assert.equal(readFileSync(join(dir, 'remote/CURRENT'), 'utf8'), `${previous}\n`);
});

for (const failure of ['FAIL_RUN', 'FAIL_HEALTH']) {
  test(`staging deploy restores last verified release on ${failure}`, (t) => {
    const { dir, archive, run } = fixture(t);
    assert.equal(run(['build', sha, 'deployment-source', archive]).status, 0);
    assert.notEqual(run(['ship', sha, archive, url], { [failure]: '1' }).status, 0);
    assert.equal(readFileSync(join(dir, 'remote/CURRENT'), 'utf8'), `${previous}\n`);
    assert.equal(readFileSync(join(dir, 'container-state/hasta-api'), 'utf8'), 'old-container');
    assert.match(readFileSync(join(dir, 'docker.log'), 'utf8'), /rm -f candidate\n[\s\S]*start old-container\n/);
  });
}

test('staging deploy cleans up an unverified first release without creating CURRENT', (t) => {
  const { dir, archive, run } = fixture(t);
  for (const file of ['container-state/hasta-api', 'remote/CURRENT']) rmSync(join(dir, file));
  assert.equal(run(['build', sha, 'deployment-source', archive]).status, 0);
  assert.notEqual(run(['ship', sha, archive, url], { FAIL_RUN: '1' }).status, 0);
  for (const file of ['container-state/hasta-api', 'remote/CURRENT', 'remote/.deployment']) {
    assert.throws(() => readFileSync(join(dir, file)), { code: 'ENOENT' });
  }
});
