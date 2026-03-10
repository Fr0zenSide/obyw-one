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
        ┌──────┬───────┼───────┬──────────┐
        │      │       │       │          │
   maya.fit  api.    api.   status.    umami.
   (static)  maya.   obyw.  obyw.one   obyw.one
             fit     one
        │      │       │       │          │
   /srv/   Docker   Native   Docker    Docker
   www/    Kuzzle   PocketB  Uptime    Umami
           :7512    :8090+   Kuma      :3000
                             :3001
```

### What Runs Where

| Service | Type | Port | Domain | Notes |
|---------|------|------|--------|-------|
| **Caddy** | Native | 80, 443 | — | Reverse proxy + TLS |
| **Landing pages** | Static | — | `maya.fit`, etc. | Served by Caddy from `/srv/www/<domain>/` |
| **Kuzzle** (Maya API) | Docker | 7512 | `api.maya.fit` | ES + Redis + Kuzzle |
| **PocketBase** (OBYW) | Native | 8091 / 8191 | `api.obyw.one` | Shared: waitlist, community, feedback |
| **PocketBase** (WabiSabi) | Native | 8090 / 8190 | `api.wabisabi.app` | Per-project instance |
| **Umami** | Docker | 3000 | `umami.obyw.one` | Analytics |
| **Uptime Kuma** | Docker | 3001 | `status.obyw.one` | Status page |

### Design Decisions

- **No API gateway** — Caddy handles reverse proxy, CORS, and security headers. Each backend handles its own auth and rate limiting. Overkill at this scale.
- **Docker for complex stacks only** — Kuzzle needs ES + Redis → Docker. PocketBase is a single binary → native.
- **Preprod + prod for PocketBase** — Each project gets two instances on different ports. Kuzzle is prod-only (will migrate to dedicated VPS).
- **Centralized landing pages** — All static sites in `landings/<domain>/`, deployed to `/srv/www/<domain>/` on the server.

---

## DNS Records

| Record | Domain |
|--------|--------|
| A | `maya.fit` |
| A | `api.maya.fit` |
| A | `api.obyw.one` |
| A | `api.wabisabi.app` |
| A | `preprod-api.wabisabi.app` |
| A | `status.obyw.one` |
| A | `umami.obyw.one` |

Caddy provisions HTTPS certificates automatically via Let's Encrypt.

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

Centralized in `landings/<domain>/`. Each subdirectory is a complete static site deployed to `/srv/www/<domain>/` on the server.

```
landings/
├── maya.fit/          ← https://maya.fit
├── wabisabi.app/      ← https://wabisabi.app (future)
└── obyw.one/          ← https://obyw.one (future)
```

### Deploy

```bash
# Single site
rsync -azP landings/maya.fit/ user@host:/srv/www/maya.fit/

# All sites
for site in landings/*/; do
  domain=$(basename "$site")
  rsync -azP "$site" "user@host:/srv/www/$domain/"
done
```

To add a new landing page:
1. Create `landings/<domain>/index.html`
2. Add a Caddy block in `deploy/Caddyfile`
3. Add a DNS A record
4. Deploy

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
| Maya.fit | `https://maya.fit` | 60s |
| Maya API | `http://localhost:7512/_healthCheck` | 60s |
| OBYW API | `http://localhost:8091/api/health` | 60s |
| WabiSabi API | `http://localhost:8090/api/health` | 60s |
| Umami | `https://umami.obyw.one` | 60s |
| Caddy | `https://maya.fit` | 60s |

---

## 6. CI/CD

### GitHub Secrets

| Secret | Value |
|--------|-------|
| `DEPLOY_HOST` | Server IP or hostname |
| `DEPLOY_USER` | SSH user (with sudo) |
| `DEPLOY_SSH_KEY` | Private SSH key (ed25519) |

### Deploy Pipeline (push to main)

Detects which files changed and deploys only what's needed:
- `landings/**` changed → rsync landing pages
- `deploy/Caddyfile` changed → validate + reload Caddy
- `pb_migrations/**` changed → rsync + restart PocketBase
- `deploy/docker-compose.kuzzle.yml` changed → docker compose up

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
