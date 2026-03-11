# Obyw.one — Deployment Infrastructure

Shared deployment infrastructure for all Obyw.one projects.
Single VPS, native-first — Docker only where the stack requires it.

## Architecture

```
                         Internet
                            │
                        ┌───┴───┐
                        │ Caddy  │  ← native systemd, auto HTTPS
                        └───┬───┘
     ┌────────┬─────┬───────┼───────┬──────────┐
     │        │     │       │       │          │
  obyw.one  maya  api.    api.   status.    umami.
  (static)  .fit  maya.   obyw.  obyw.one   obyw.one
            (st.) fit     one
     │        │     │       │       │          │
  /srv/www/ /srv/ Docker  Native  Docker    Docker
  obyw-one/ www/  Kuzzle  PocketB Uptime    Umami
            maya  :7512   :8090+  Kuma      :3000
            -fit/                 :3001
```

### Source of Truth

All landing pages live in the **private `obyw-one` repo** under `landings/`.
GitHub Actions deploys to VPS on push to `main`.
No GitHub Pages — everything served directly by Caddy on the VPS.

### What Runs Where

| Service | Type | Port | Domain | Notes |
|---------|------|------|--------|-------|
| **Caddy** | Native | 80, 443 | — | Reverse proxy + TLS |
| **Landing pages** | Static | — | `obyw.one`, `maya.fit`, etc. | Served by Caddy from `/srv/www/<domain>/` |
| **Kuzzle** (Maya API) | Docker | 7512 | `api.maya.fit` | ES + Redis + Kuzzle |
| **PocketBase** (OBYW) | Native | 8091 | `api.obyw.one` | Shared: waitlist, community, feedback (prod only) |
| **PocketBase** (WabiSabi) | Native | 8090 / 8190 | `wabisabi.obyw.one` | Per-project instance |
| **Umami** | Docker | 3000 | `umami.obyw.one` | Analytics |
| **Uptime Kuma** | Docker | 3001 | `status.obyw.one` | Status page |
| **ntfy** | Docker | 2586 | `ntfy.obyw.one` | Push notifications for apps |

### Design Decisions

- **No API gateway** — Caddy handles reverse proxy, CORS, and security headers. Each backend handles its own auth and rate limiting. Overkill at this scale.
- **Docker for complex stacks only** — Kuzzle needs ES + Redis → Docker. PocketBase is a single binary → native.
- **Preprod + prod for PocketBase** — Each project gets two instances on different ports. Kuzzle is prod-only (will migrate to dedicated VPS).
- **Centralized landing pages** — All static sites in `landings/<domain>/`, deployed to `/srv/www/<domain>/` on the server.

---

## DNS Records

All domains point to VPS (`92.134.242.73`). Caddy provisions HTTPS automatically via Let's Encrypt.

| Domain | Type | Target | Service |
|--------|------|--------|---------|
| `obyw.one` | A | `92.134.242.73` | Landing page |
| `www.obyw.one` | CNAME | `obyw.one.` | → redirect to root |
| `maya.fit` | A | `92.134.242.73` | Landing page |
| `www.maya.fit` | CNAME | `maya.fit.` | → redirect to root |
| `api.maya.fit` | A | `92.134.242.73` | Kuzzle backend |
| `api.obyw.one` | A | `92.134.242.73` | PocketBase (OBYW) |
| `wabisabi.obyw.one` | A | `92.134.242.73` | PocketBase (WabiSabi) |
| `wabisabi-preprod.obyw.one` | A | `92.134.242.73` | PocketBase (WabiSabi preprod) |
| `status.obyw.one` | A | `92.134.242.73` | Uptime Kuma |
| `umami.obyw.one` | A | `92.134.242.73` | Analytics |
| `ntfy.obyw.one` | A | `92.134.242.73` | Push notifications |

### OVH Setup Per Domain

For each root domain (`obyw.one`, `maya.fit`):
1. Add **1 A record** for `@` → `92.134.242.73`
2. Add **CNAME** for `www` → `<domain>.` (with trailing dot)
3. Delete any GitHub Pages A records (185.199.x.x) if they exist
4. Keep MX, SPF, NS records untouched

---

## 1. Caddy (Reverse Proxy)

Native install, manages all routing and TLS. Uses Caddy snippets for shared security headers, CORS, and logging.

```bash
# Install (Debian/Ubuntu)
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install caddy

# Deploy config
sudo cp deploy/Caddyfile /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

---

## 2. Kuzzle (Maya Backend)

Docker Compose: Kuzzle 2 + Elasticsearch 7 + Redis 7.

```bash
cd /opt/kuzzle
cp deploy/docker-compose.kuzzle.yml docker-compose.yml
docker compose up -d

# Health check
curl -sf http://localhost:7512/_healthCheck | jq .status

# Logs
docker compose logs -f kuzzle
```

Resources: ES ~512MB heap, Redis ~10MB, Kuzzle ~150MB. Will migrate to dedicated VPS later.

---

## 3. PocketBase (Multi-Instance)

Single shared binary, multiple instances via systemd template service.

### Directory Structure

```
/opt/pocketbase/
├── pocketbase                    ← shared binary (v0.25.9)
└── instances/
    ├── wabisabi/
    │   ├── prod/                 ← port 8090
    │   │   ├── pb_data/
    │   │   └── pb_migrations/
    │   └── preprod/              ← port 8190
    └── obyw/
        ├── prod/                 ← port 8091
        │   ├── pb_data/
        │   └── pb_migrations/
        └── preprod/              ← port 8191
```

### Port Convention

| Project | Prod | Preprod |
|---------|------|---------|
| WabiSabi | 8090 | 8190 |
| OBYW | 8091 | 8191 |

Rule: `80X0` = prod, `81X0` = preprod.

### Setup

```bash
# Install binary + systemd template
sudo bash deploy/setup-pocketbase.sh

# Bootstrap all 4 instances
sudo bash deploy/setup-pocketbase.sh bootstrap

# Or add individually
sudo bash deploy/setup-pocketbase.sh add obyw prod 8091

# List / remove
sudo bash deploy/setup-pocketbase.sh list
sudo bash deploy/setup-pocketbase.sh remove obyw tmp
```

### Manage

```bash
systemctl status pocketbase@obyw-prod
systemctl restart pocketbase@wabisabi-preprod
journalctl -u pocketbase@obyw-prod -f
```

### Deploy Migrations

```bash
rsync -azP pb_migrations/ user@host:/opt/pocketbase/instances/obyw/prod/pb_migrations/
ssh user@host 'sudo systemctl restart pocketbase@obyw-prod'
```

---

## 4. Landing Pages

All landing pages live in a **single private repo** (`Fr0zenSide/obyw-one`) under `landings/`.
Each subdirectory is a complete static site deployed to `/srv/www/<domain>/` on the server.
No GitHub Pages — Caddy serves everything directly with auto-HTTPS.

```
obyw-one/
├── landings/
│   ├── obyw-one/        ← https://obyw.one (portfolio root)
│   ├── maya-fit/         ← https://maya.fit
│   └── wabisabi-app/     ← https://wabisabi.app (future)
├── deploy/
│   ├── Caddyfile
│   ├── docker-compose.kuzzle.yml
│   └── ...
├── .github/
│   └── workflows/
│       └── deploy.yml    ← auto-deploy on push to main
└── pb_migrations/
```

### Manual Deploy

```bash
# Single site
rsync -azP landings/maya-fit/ user@host:/srv/www/maya.fit/

# All sites
for dir in landings/*/; do
  domain=$(basename "$dir" | sed 's/-/./g')
  rsync -azP "$dir" "user@host:/srv/www/$domain/"
done
```

### Add a New Landing Page

1. Create `landings/<name>/index.html` (use folder name with dashes: `maya-fit`)
2. Add a Caddy block in `deploy/Caddyfile`:
   ```caddy
   newdomain.com, www.newdomain.com {
       import security_headers
       root * /srv/www/newdomain.com
       file_server
   }
   ```
3. Add DNS A record for `newdomain.com` → `92.134.242.73` + CNAME `www` → `newdomain.com.`
4. Push to `main` → GitHub Actions deploys automatically
5. Caddy auto-provisions HTTPS on first request

---

## 5. Monitoring

### Uptime Kuma

```bash
cd /opt/monitoring
cp deploy/docker-compose.monitoring.yml docker-compose.yml
docker compose up -d
```

Open `https://status.obyw.one`, create admin, add monitors from `monitors.json`.

### Monitored Endpoints

| Service | Check | Interval |
|---------|-------|----------|
| Obyw.one | `https://obyw.one` | 60s |
| Maya.fit | `https://maya.fit` | 60s |
| Maya API | `http://localhost:7512/_healthCheck` | 60s |
| OBYW API | `http://localhost:8091/api/health` | 60s |
| WabiSabi API | `http://localhost:8090/api/health` | 60s |
| Umami | `https://umami.obyw.one` | 60s |
| Status | `https://status.obyw.one` | 120s |

---

## 6. CI/CD (GitHub Actions)

Single private repo (`Fr0zenSide/obyw-one`), smart deploy on push to `main`.

### GitHub Secrets

| Secret | Value |
|--------|-------|
| `DEPLOY_HOST` | `92.134.242.73` |
| `DEPLOY_USER` | SSH user (with sudo) |
| `DEPLOY_SSH_KEY` | Private SSH key (ed25519) |

### Deploy Pipeline (push to main)

`.github/workflows/deploy.yml` detects which files changed and deploys only what's needed:

| Changed path | Action |
|-------------|--------|
| `landings/**` | rsync changed sites to `/srv/www/<domain>/` |
| `deploy/Caddyfile` | validate + backup + reload Caddy |
| `pb_migrations/**` | rsync + restart PocketBase |
| `deploy/docker-compose.kuzzle.yml` | docker compose up |

### Workflow Summary

```
push to main
    │
    ├─ detect changed files (git diff)
    │
    ├─ landings changed?
    │   └─ rsync landings/<name>/ → /srv/www/<domain>/
    │
    ├─ Caddyfile changed?
    │   └─ validate → backup → copy → reload
    │
    ├─ pb_migrations changed?
    │   └─ backup pb_data → rsync migrations → restart
    │
    └─ docker-compose changed?
        └─ docker compose up -d
```

No build step for landing pages (plain HTML/CSS/JS). If a landing page ever needs a build (e.g., Astro), add a build step before rsync.

---

## 7. Dynamic DNS (OVH DynHost)

The VPS is behind a Livebox (home router) with a dynamic public IP. OVH DynHost keeps DNS records in sync when the IP changes.

**Why not ddclient?** OVH rejects batch hostname updates (`hostname=a,b,c`), and ddclient v3.10 batches all entries with the same login. A simple curl script works reliably.

### OVH Manager Setup

For each domain, create DynHost records and credentials:

1. Go to **Web Cloud** → **Domain Names** → select domain → **DynHost** tab
2. **Add a DynHost** for each subdomain (one entry per subdomain, current IP as value)
3. **Manage accesses** → **Create a login** (suffix: `Admin`, subdomain: `*`)

Credentials format: `<domain>-<suffix>` (e.g., `obyw.one-Admin`, `maya.fit-Admin`).

> **Important**: DynHost records replace regular A records. Delete existing A records for a subdomain before creating its DynHost entry.

### Updater Script

`/usr/local/bin/ovh-dyndns.sh` — updates each hostname individually via OVH's DynDNS2 API:

```bash
#!/bin/bash
# OVH DynHost updater — one request per hostname

IP=$(curl -4 -sf https://api.ipify.org)
if [ -z "$IP" ]; then
  logger -t ovh-dyndns "Failed to get public IP"
  exit 1
fi

update() {
  local login="$1" pass="$2" host="$3"
  local resp
  resp=$(curl -4 -sf -u "${login}:${pass}" \
    "https://www.ovh.com/nic/update?system=dyndns&hostname=${host}&myip=${IP}")
  logger -t ovh-dyndns "${host}: ${resp}"
}

# ─── obyw.one ───
update "obyw.one-Admin"   '<password>' "obyw.one"
update "obyw.one-Admin"   '<password>' "api.obyw.one"
update "obyw.one-Admin"   '<password>' "umami.obyw.one"
update "obyw.one-Admin"   '<password>' "status.obyw.one"
update "obyw.one-Admin"   '<password>' "wabisabi.obyw.one"
update "obyw.one-Admin"   '<password>' "wabisabi-preprod.obyw.one"
update "obyw.one-Admin"   '<password>' "ntfy.obyw.one"

# ─── maya.fit ───
update "maya.fit-Admin"   '<password>' "maya.fit"
update "maya.fit-Admin"   '<password>' "api.maya.fit"
```

### Install

```bash
sudo install -m 700 /dev/stdin /usr/local/bin/ovh-dyndns.sh  # paste script
echo '*/5 * * * * root /usr/local/bin/ovh-dyndns.sh' | sudo tee /etc/cron.d/ovh-dyndns
```

### Verify

```bash
# Manual run
sudo /usr/local/bin/ovh-dyndns.sh

# Check logs
journalctl -t ovh-dyndns --no-pager

# Expected responses:
#   good 92.134.242.73    — updated
#   nochg 92.134.242.73   — already correct
#   nohost                — DynHost entry missing in OVH
#   badauth               — wrong login/password
```

### Route Cache Fix

Docker can corrupt the kernel route cache (broadcast bug), breaking all outbound connections. Safety net:

```bash
echo '*/30 * * * * root ip route flush cache' | sudo tee /etc/cron.d/route-cache-flush
```

Symptom: `ip route get 8.8.8.8` returns `broadcast 8.8.8.8`. Fix: `sudo ip route flush cache`.

---

## Quick Reference

### Start Everything

```bash
# Native
sudo systemctl start caddy
sudo systemctl start pocketbase@obyw-prod
sudo systemctl start pocketbase@wabisabi-prod

# Docker
cd /opt/kuzzle && docker compose up -d
cd /opt/monitoring && docker compose up -d
```

### Health Checks

```bash
curl -sf https://maya.fit > /dev/null && echo "OK"
curl -sf http://localhost:7512/_healthCheck | jq .status
curl -sf http://localhost:8090/api/health
curl -sf http://localhost:8091/api/health
curl -sf http://localhost:3001 > /dev/null && echo "OK"
```

### Backups

```bash
# PocketBase
tar czf pb-obyw-$(date +%Y%m%d).tar.gz /opt/pocketbase/instances/obyw/prod/pb_data/

# Kuzzle (Elasticsearch)
docker exec maya-elasticsearch curl -sf -XPUT "localhost:9200/_snapshot/backup" \
  -H 'Content-Type: application/json' \
  -d '{"type":"fs","settings":{"location":"/usr/share/elasticsearch/data/backup"}}'

# Uptime Kuma
docker run --rm -v uptime-kuma-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/uptime-kuma-$(date +%Y%m%d).tar.gz /data
```

---

## Files

| File | Purpose |
|------|---------|
| `deploy/Caddyfile` | All reverse proxy routes (snippets, CORS, security headers, logging) |
| `deploy/docker-compose.kuzzle.yml` | Kuzzle + Elasticsearch + Redis |
| `deploy/docker-compose.monitoring.yml` | Uptime Kuma |
| `deploy/setup-pocketbase.sh` | Multi-instance PocketBase installer (nested project/env dirs) |
| `deploy/monitors.json` | Uptime Kuma monitor definitions |
| `deploy/email-signature.html` | Professional email signature with Umami tracking |
| `pb_migrations/` | OBYW PocketBase schema migrations |
| `landings/` | Static landing pages per domain |
| `/usr/local/bin/ovh-dyndns.sh` | DynDNS updater script (on VPS, not in repo — contains credentials) |
| `/etc/cron.d/ovh-dyndns` | Runs DynDNS update every 5 minutes |
| `/etc/cron.d/route-cache-flush` | Flushes route cache every 30 min (Docker bug workaround) |
