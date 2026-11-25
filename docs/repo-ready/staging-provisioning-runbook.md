# Hasta Staging Provisioning Runbook (VPS @ 149.28.136.202)

> Update: a real staging host now exists. VPS created (Vultr-class), so the
> previous `Hasta staging QA` DNS/`NXDOMAIN` block is no longer a "no host"
> problem. It is now a "configure + point DNS + deploy" problem.

## Server facts (from creation confirmation)

| Item | Value |
| --- | --- |
| Public IPv4 | 149.28.136.202 |
| OS | Ubuntu 24.04 LTS x64 |
| RAM | 1024 MB (1 GB) |
| Storage | 25 GB |
| Location | Singapore |
| Label / host | api.nexusmmr.com |

> IMPORTANT DOMAIN CHANGE: the staging host label is now `api.nexusmmr.com`,
> not `api-social.hasta.app`. All DNS + health-probe targets below must use
> `api.nexusmmr.com`. Update `.hastaSTATE.md` and the CI health-check base URL
> to this domain before the next QA run.

## CRITICAL: 1 GB RAM is tight

Nest API + Postgres + Cloudflare tunnel + build tooling will NOT all fit
comfortably in 1 GB. Do this first or builds/OOM-kill will silently fail.

```bash
# 1. Add 2 GB swap (mandatory on a 1 GB box)
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
sudo sysctl vm.swappiness=10
# 2. Keep Postgres OFF this box for staging -> use a managed/free Postgres
#    (Neon / Supabase free tier) so the VPS only runs the API.
```

## Provisioning steps

### A. Connect + harden SSH
```bash
ssh root@149.28.136.202
adduser hasta && usermod -aG sudo hasta
rsync --archive --chown=hasta:hasta ~/.ssh /home/hasta   # copy key
sudo ufw allow OpenSSH && sudo ufw allow 80 && sudo ufw allow 443 && sudo ufw enable
```

### B. Runtime on the box (as `hasta`)
```bash
# Node 20 + git
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs git
node -v && npm -v
# Cloudflare named tunnel (NOT quick tunnel) for a stable hostname
sudo curl -L --output /usr/local/bin/cloudflared \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
cloudflared --version
```

### C. DNS -> this server
At your DNS provider for `nexusmmr.com`, add:
```
Type: A     Name: api     Value: 149.28.136.202     TTL: 60 (temporary, lower is fine)
```
Verify propagation (the whole earlier block was NXDOMAIN):
```bash
dig +short api.nexusmmr.com        # must return 149.28.136.202
```
When this returns the IP instead of NXDOMAIN, the DNS blocker is cleared.

### D. Deploy the API to the box
```bash
git clone <repo> ~/hasta && cd ~/hasta && git checkout <s2-or-deploy-branch>
cp .env.staging.example .env       # fill DATABASE_URL (managed PG), JWT, secrets ONLY here
npm ci && npm run build
# run under a process manager so it survives SSH drop:
sudo npm i -g pm2
pm2 start dist/main.js --name hasta-api --env production
pm2 save && pm2 startup
```

### E. HTTPS + the deployed-SHA /health contract
```bash
sudo apt-get install -y caddy      # Caddy auto-TLS for api.nexusmmr.com
sudo tee /etc/caddy/Caddyfile >/dev/null <<'CFG'
api.nexusmmr.com {
    reverse_proxy 127.0.0.1:3000
}
CFG
sudo systemctl reload caddy

# Bake the git SHA so /health can echo the deployed revision:
cd ~/hasta
echo "GIT_COMMIT=$(git rev-parse HEAD)" >> .env
# ensure the Nest /health handler returns { "commit": process.env.GIT_COMMIT }
pm2 restart hasta-api --update-env
```
Pass criterion for health: `curl https://api.nexusmmr.com/health` returns HTTP 200
AND its `commit` field equals `git rev-parse HEAD` in the checkout that built the
running process. If the box is behind a firewall/proxy you can still expose 443 via
Cloudflare Tunnel instead of Caddy — pick ONE path, do not run both.

### F. Isolated staging DB + synthetic fixtures
```bash
# point .env DATABASE_URL at the MANAGED staging Postgres (never prod)
npm run migration:run
npm run seed:staging            # synthetic fixtures only
```

### G. Staging APK flavor
Build the staging-flavored Android APK pointing at `https://api.nexusmmr.com`
(flavor = staging). Confirm `flutter build apk --flavor staging` succeeds before QA.

### H. (Separate fix) Native T40/T41 12-min timeout
The 12-minute hang is most likely tests polling a guest-auth endpoint that does
not exist while **S1 is still open**. Fix either:
- merge S1 guest auth first, THEN re-run T40/T41; or
- tag T40/T41 as `skipped (S1 not ready)` so CI fails fast / skips cleanly
  instead of hanging 12 min.

## GitHub Actions deploy-staging.yml (so deployments are recorded, not just Pages)
```yaml
name: deploy-staging
on:
  push:
    branches: [ main ]
jobs:
  deploy:
    environment: staging        # creates a real staging deployment record
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ssh hasta@149.28.136.202 'cd ~/hasta && git pull && npm ci && npm run build && pm2 restart hasta-api --update-env'
        # GIT_COMMIT baked from ${{ github.sha }} into .env during deploy
```
After this workflow runs once, GitHub deployment records will list a `staging`
deployment (not only GitHub Pages), and the deployed SHA is registered.

## Ready-when checklist (all green -> run QA)
- [ ] `dig +short api.nexusmmr.com` returns 149.28.136.202 (no NXDOMAIN)
- [ ] `curl https://api.nexusmmr.com/health` -> HTTP 200, commit == deployed SHA
- [ ] staging DB migrated + synthetic fixtures seeded (isolated from prod)
- [ ] GitHub `staging` environment + deployment record exists
- [ ] staging APK flavor built
- [ ] T40/T41 either un-blocked (S1 merged) or explicitly skipped

## Then run QA
```
Hasta staging QA https://api.nexusmmr.com/health <deployed SHA> — isolated staging + synthetic fixtures confirmed
```
PR #2 stays draft @ c8e0639 and `main` untouched until every gate above is green.
