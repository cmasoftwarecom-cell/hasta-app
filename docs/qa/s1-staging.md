# S1 staging QA checklist

Status: **blocked on a verified public HTTPS `/health` response**. The isolated CI API is not staging. Record the staging deployment revision, app build and device/OS, date in UTC, and test verdicts on PR #2 before marking this gate complete.

## Prerequisites

- Obtain the approved HTTPS staging API URL and confirm that it points to the PR revision, with the enrollment migration applied and a database and signing keys distinct from production.
- Use an approved synthetic install or dedicated staging device. Use a normal release-mode build for guest checks. If testing the QA picker, use a separate approved debug test/beta build and never enable the server flag on production.
- Do not put credentials, proof values, raw device identifiers, tokens, or test account details in evidence. Capture only build identifiers, step verdicts and redacted diagnostics.

## Diagnose and configure the origin

SSH as the authorized operator. Set `STAGING_HOST` to the approved DNS name, not the origin IP. Run these from the deployed checkout if using Compose:

```sh
ssh "$SSH_USER@$ORIGIN_IP"
# On the server, set STAGING_HOST to the approved HTTPS hostname.
sudo systemctl is-active nginx
sudo ss -ltnp '( sport = :80 or sport = :443 or sport = :3000 )'
docker compose ps server postgres redis
# If NestJS is managed by systemd instead: sudo systemctl status "$HASTA_API_UNIT" --no-pager
curl --fail-with-body --max-time 5 http://127.0.0.1:3000/health
sudo nginx -t
curl --fail-with-body --max-time 5 \
  --resolve "$STAGING_HOST:443:127.0.0.1" "https://$STAGING_HOST/health"
```

The backend probe is `GET /health`, not `GET /v1/health`. Require `200` with `{"status":"ok"}` from the backend before changing Cloudflare. If the backend check fails, inspect the approved service's startup logs locally, check the bind/published port and isolated staging database, and verify deployment of the Prisma migrations from the intended revision. The development Compose settings are not a staging deployment definition. Do not paste credentials or unredacted logs into the PR.

If NestJS is listening on host loopback, use this shape for the staging Nginx vhost. Substitute `STAGING_HOST` and the paths to an already installed certificate and key before loading it. Keep port 3000 off the public interface. If Nginx is also containerized, use the backend's service name on the private Docker network instead of host loopback.

```nginx
server {
    listen 80;
    server_name STAGING_HOST;
    return 301 https://STAGING_HOST$request_uri;
}

server {
    listen 443 ssl;
    server_name STAGING_HOST;

    ssl_certificate     /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

Do not append a URI to `proxy_pass`: the origin must receive `/health` and `/v1/...` unchanged. Back up the existing vhost, then apply with `sudo nginx -t && sudo systemctl reload nginx`. For a DNS-only record, the origin must serve a publicly trusted certificate with the staging hostname. If proxying is intended, check that the exact record is set to **Proxied** in Cloudflare DNS and that the edge certificate is active. Confirm origin HTTPS on 443 with a matching and unexpired public or Cloudflare Origin CA certificate, then use [Full (strict)](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/). Avoid changing unrelated hostnames; check the scope of any TLS setting before applying it. Do not use Flexible or non-validating Full as a workaround. If an Origin CA certificate is intentionally used behind the proxy, validate direct origin checks with the trusted Origin CA root (`curl --cacert`); don't use `-k`. From a separate network, verify public HTTPS without a certificate override:

```sh
curl -sS --max-time 10 -D - -o /dev/null "http://$STAGING_HOST/health"
curl --fail-with-body --max-time 10 -i "https://$STAGING_HOST/health"
```

## Twelve-item smoke checklist

| Check | Action and expected result |
| --- | --- |
| 01 · Routing | Confirm the intended public DNS target/proxy mode and the approved staging revision. |
| 02 · TLS | HTTP redirects to HTTPS; HTTPS validates the chain, validity and hostname without a bypass. |
| 03 · Health | Local backend and public `GET /health` return `200`. Staging returns `status: ok`, `env: staging`, and the exact full commit SHA from the image. Non-staging keeps the minimal probe. `/v1/health` is not the probe. |
| 04 · Isolation | Confirm migrations, isolated DB/signing keys, no production users, and approved synthetic fixture scope before any write. |
| 05 · Entry (T20/T37) | Welcome presents only Continue as the primary guest entry; no OTP or Google/Apple sign-in. |
| 06 · Entry (T40) | Fresh native install: one tap opens the guest profile. Confirm `is_guest=true` and an active session using approved read-only telemetry. |
| 07 · Relaunch (T40) | Close and reopen the app; it restores the same account without another enrollment. |
| 08 · Re-entry (T41) | Sign out and continue again on the same install. The same guest account resumes without duplicates, and the old session stays revoked. |
| 09 · Cooldown (T42) | Use a pre-provisioned synthetic cooldown install and verify `device_cooldown` and retry timing. Do not mutate a real user's account. |
| 10 · QA exclusion (T36) | Release app has no fixture panel after a three-second hold. If approved, seed and open fixtures only through the approved enabled test/beta backend and a non-release build. |
| 11 · Family revocation (T46) | Verify the isolated CI family-revocation test for the deployed revision. Run the staging case only with an approved pair of synthetic fixtures. |
| 12 · Offline | With a cached profile, disable networking and reopen. The profile is readable with an offline notice; reconnect and retry. |

Run on Android and iOS where signed staging builds are available. Record any failures or untested cases; a green CI artifact scan does not substitute for the staging results.

## Build and verify the staging image

From a clean checkout of the approved revision, build from the server context:

```sh
sha="$(git rev-parse HEAD)"
docker build --build-arg GIT_COMMIT="$sha" -t "hasta-api:$sha" apps/server
```

Use the approved isolated staging configuration with `HASTA_ENV=staging`. The SHA is baked into the image; setting `GIT_COMMIT` at container runtime does not change what `/health` reports. A staging image without a valid baked SHA returns HTTP 503. This check verifies the deployment's reported build identity, not database readiness or fixture isolation.

```sh
bash docs/repo-ready/verify-staging.sh "$STAGING_BASE_URL" "$sha"
```
