#!/usr/bin/env bash
set -euo pipefail

mode=${1:?build or ship}
sha=${2:?full deployment SHA}
[[ $sha =~ ^[0-9a-f]{40}$ ]] || { echo 'Expected a full deployment SHA.' >&2; exit 1; }
image="hasta-api:$sha"

case "$mode" in
  build)
    source=${3:?source checkout}
    archive=${4:?archive path}
    docker build --build-arg "GIT_COMMIT=$sha" --tag "$image" "$source/apps/server"
    baked="$(docker run --rm --entrypoint cat "$image" /app/dist/build-commit)" || baked=
    if [[ $baked != "$sha" ]]; then
      echo 'Image is missing the expected baked commit SHA; select a revision with the staging health contract.' >&2
      exit 1
    fi
    docker save "$image" | gzip > "$archive"
    ;;
  ship)
    archive=${3:?archive path}
    health_url=${4:?public staging URL}
    [[ -s $archive ]] || { echo 'The staging image archive is empty or missing.' >&2; exit 1; }
    gzip -t -- "$archive"
    : "${STAGING_SSH_HOST:?}" "${STAGING_SSH_USER:?}" "${STAGING_SSH_KEY:?}" "${STAGING_SSH_KNOWN_HOSTS:?}"
    umask 077
    auth="$(mktemp -d)"
    trap 'rm -rf -- "$auth"' EXIT
    printf '%s\n' "$STAGING_SSH_KEY" > "$auth/key"
    printf '%s\n' "$STAGING_SSH_KNOWN_HOSTS" > "$auth/known_hosts"

    remote=$(cat <<'REMOTE'
set -euo pipefail
umask 077
phase=$1
sha=$2
owner=$3
image="hasta-api:$sha"
release="/srv/hasta/releases/$sha"
env_file=/etc/hasta/api.env
txn=/srv/hasta/.deployment
backup="hasta-api-previous-$owner"
container_named() { docker container ls -aq --filter "name=^/$1$"; }

if [[ $phase != stage ]]; then
  if [[ ! -f $txn/owner || $(<"$txn/owner") != "$owner" ]]; then
    [[ $phase == rollback ]] && exit 0
    echo 'Staging deployment transaction is not owned by this run.' >&2
    exit 1
  fi
  old="$(container_named "$backup")"
  if [[ $phase == rollback ]]; then
    candidate="$(docker container ls -aq --filter "label=hasta.deploy=$owner")"
    if [[ -n $candidate ]]; then docker rm -f "$candidate"; fi
    if [[ -n $old ]]; then docker rename "$old" hasta-api; fi
    if [[ -s $txn/running ]]; then docker start "$(<"$txn/running")"; fi
  else
    printf '%s\n' "$sha" > "$txn/current"
    mv -f -- "$txn/current" /srv/hasta/CURRENT
    if [[ -n $old ]]; then docker rm "$old" || echo 'Stopped backup retained; clean it up manually.' >&2; fi
  fi
  rm -rf -- "$txn"
  exit
fi

if [[ $(grep '^HASTA_ENV=' "$env_file") != HASTA_ENV=staging ]]; then
  echo 'Expected HASTA_ENV=staging in the staging container env file.' >&2
  exit 1
fi
mkdir -p "$release"
upload="$(mktemp "$release/api.tar.gz.XXXXXX")"
trap 'rm -f -- "$upload"' EXIT
cat > "$upload"
gzip -t -- "$upload"
gzip -dc -- "$upload" | docker load
docker image inspect "$image" >/dev/null
mv -f -- "$upload" "$release/api.tar.gz"
mkdir "$txn" || { echo 'Resolve the previous staging deployment transaction before retrying.' >&2; exit 1; }
printf '%s\n' "$owner" > "$txn/owner"
current="$(container_named hasta-api)"
if [[ -n $current ]]; then
  running="$(docker inspect --format '{{.State.Running}}' "$current")"
  docker rename "$current" "$backup"
  if [[ $running == true ]]; then
    printf '%s\n' "$current" > "$txn/running"
    docker stop "$current"
  fi
fi
docker run -d --pull=never --name hasta-api --label "hasta.deploy=$owner" --restart always \
  --env-file "$env_file" -p 127.0.0.1:3000:3000 "$image"
REMOTE
)
    # Quote for the remote login shell; the phase, SHA and owner are restricted tokens.
    remote=${remote//\'/\'\\\'\'}
    owner=${auth##*.}
    [[ $owner =~ ^[a-zA-Z0-9]+$ ]]
    remote_phase() {
      ssh -T -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes \
        -o GlobalKnownHostsFile=/dev/null -o "UserKnownHostsFile=$auth/known_hosts" \
        -o ConnectTimeout=15 -i "$auth/key" -l "$STAGING_SSH_USER" -- "$STAGING_SSH_HOST" \
        "bash -c '$remote' bash $1 $sha $owner"
    }
    pending=true
    cleanup() {
      if [[ $pending == true ]]; then
        remote_phase rollback </dev/null || echo 'Automatic rollback failed; operator recovery is required.' >&2
      fi
      rm -rf -- "$auth"
    }
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    remote_phase stage < "$archive"
    bash docs/repo-ready/verify-staging.sh "$health_url" "$sha"
    # Do not undo a verified release if the commit reply is lost.
    pending=false
    remote_phase commit </dev/null
    ;;
  *) echo 'Expected build or ship.' >&2; exit 1 ;;
esac
