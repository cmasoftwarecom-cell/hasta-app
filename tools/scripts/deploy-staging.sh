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
sha=$1
image="hasta-api:$sha"
release="/srv/hasta/releases/$sha"
env_file=/etc/hasta/api.env
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
current="$(docker container ls -aq --filter 'name=^/hasta-api$')"
if [[ -n $current ]]; then
  docker stop hasta-api
  docker rm hasta-api
fi
docker run -d --pull=never --name hasta-api --restart always \
  --env-file "$env_file" -p 127.0.0.1:3000:3000 "$image"
printf '%s\n' "$sha" > /srv/hasta/CURRENT.tmp
mv -f -- /srv/hasta/CURRENT.tmp /srv/hasta/CURRENT
REMOTE
)
    # Quote the command for the remote login shell; only the validated SHA is interpolated as an argument.
    remote=${remote//\'/\'\\\'\'}
    ssh -T -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes \
      -o GlobalKnownHostsFile=/dev/null -o "UserKnownHostsFile=$auth/known_hosts" \
      -o ConnectTimeout=15 -i "$auth/key" -l "$STAGING_SSH_USER" -- "$STAGING_SSH_HOST" \
      "bash -c '$remote' bash $sha" < "$archive"
    ;;
  *) echo 'Expected build or ship.' >&2; exit 1 ;;
esac
