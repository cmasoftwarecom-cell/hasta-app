import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gunzipSync } from 'node:zlib';
import { test } from 'node:test';

const repo = new URL('../../', import.meta.url);
const workflow = readFileSync(new URL('.github/workflows/deploy-staging.yml', repo), 'utf8');
const script = fileURLToPath(new URL('tools/scripts/deploy-staging.sh', repo));
const sha = 'a'.repeat(40);

test('staging deploy wires the server image build to the protected manual job', () => {
  assert.match(workflow, /workflow_dispatch:/);
  assert.doesNotMatch(workflow, /(?:^|\n)  (?:push|pull_request):/);
  assert.match(workflow, /if: github\.ref == 'refs\/heads\/main'/);
  assert.match(workflow, /environment:\s*\n\s+name: staging/);
  assert.match(workflow, /git -C deployment-source merge-base --is-ancestor "\$sha" origin\/main/);
  assert.match(workflow, /deploy-staging\.sh build "\$DEPLOY_SHA" deployment-source "\$RUNNER_TEMP\/api\.tar\.gz"/);
});

test('staging deploy sends the built archive before running the tracked verifier', () => {
  const ship = workflow.indexOf('deploy-staging.sh ship "$DEPLOY_SHA" "$RUNNER_TEMP/api.tar.gz"');
  const verify = workflow.indexOf('bash docs/repo-ready/verify-staging.sh https://api-staging.hasta.app "$DEPLOY_SHA"');
  assert.ok(ship >= 0 && verify > ship);
  assert.doesNotMatch(workflow, /api\.tar\.gz\s*<\s*\/dev\/null/);
});

function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), 'hasta-deploy-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const archive = join(dir, 'api.tar.gz');
  for (const [name, body] of Object.entries({
    docker: `
printf '%s\\n' "$*" >> "$RUNNER_TEMP/docker.log"
case "$1" in
  run) if [[ "$2" == --rm ]]; then printf '%s' "$BAKED"; fi ;;
  save) printf '%s' 'synthetic docker archive' ;;
  load)
    [[ $(cat) == 'synthetic docker archive' ]]
    [[ \${FAIL_LOAD:-0} == 0 ]]
    ;;
  container) printf '%s' 'old-container' ;;
esac`,
    ssh: `
[[ ! -s "$RUNNER_TEMP/ssh-request" ]]
printf '%s\\n' "$*" > "$RUNNER_TEMP/ssh-request"
cat > "$RUNNER_TEMP/received"
command=\${!#}
command=\${command//\\/srv\\/hasta/$RUNNER_TEMP\\/remote}
command=\${command//\\/etc\\/hasta\\/api.env/$RUNNER_TEMP\\/api.env}
sh -c "$command" < "$RUNNER_TEMP/received"
`,
  })) writeFileSync(join(dir, name), `#!/usr/bin/env bash\nset -eu\n${body}\n`, { mode: 0o700 });
  writeFileSync(join(dir, 'api.env'), 'HASTA_ENV=staging\n');
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
  const ship = run(['ship', sha, archive]);
  assert.equal(ship.status, 0, ship.stderr);
  assert.deepEqual(readFileSync(join(dir, 'received')), readFileSync(archive));
  assert.equal(gunzipSync(readFileSync(archive)).toString(), 'synthetic docker archive');
  assert.match(readFileSync(join(dir, 'ssh-request'), 'utf8'), /StrictHostKeyChecking=yes/);
  assert.equal(readFileSync(join(dir, 'remote', 'CURRENT'), 'utf8'), `${sha}\n`);
  const calls = readFileSync(join(dir, 'docker.log'), 'utf8');
  assert.ok(calls.indexOf('load\n') < calls.indexOf('stop hasta-api\n'));
  assert.match(calls, /stop hasta-api\nrm hasta-api\nrun -d --pull=never/);
});

test('staging deploy stops before shipping if SHA metadata or archive is missing', (t) => {
  const { dir, archive, run } = fixture(t);
  const build = run(['build', sha, 'deployment-source', archive], { BAKED: '' });
  assert.notEqual(build.status, 0);
  assert.match(build.stderr, /baked commit SHA/);
  assert.doesNotMatch(readFileSync(join(dir, 'docker.log'), 'utf8'), /^save /m);
  writeFileSync(archive, '');
  assert.notEqual(run(['ship', sha, archive]).status, 0);
  assert.throws(() => readFileSync(join(dir, 'ssh-request')), { code: 'ENOENT' });
});

test('staging deploy leaves the current container untouched if the remote docker load fails', (t) => {
  const { dir, archive, run } = fixture(t);
  assert.equal(run(['build', sha, 'deployment-source', archive]).status, 0);
  assert.notEqual(run(['ship', sha, archive], { FAIL_LOAD: '1' }).status, 0);
  const calls = readFileSync(join(dir, 'docker.log'), 'utf8');
  assert.match(calls, /^load$/m);
  assert.doesNotMatch(calls, /^(?:stop|rm|run -d) /m);
  assert.throws(() => readFileSync(join(dir, 'remote', 'CURRENT')), { code: 'ENOENT' });
});
