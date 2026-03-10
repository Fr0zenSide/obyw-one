# DNS Setup — OVH → VPS (Caddy)

How to point OVH-managed domains to the VPS for all services.
All domains point to `92.134.242.73`. Caddy handles HTTPS via Let's Encrypt.

## Per-domain setup

### obyw.one (portfolio root + landing page)

| Type  | Subdomain |      Target      | TTL  |
|-------|-----------|------------------|------|
| A     | *(empty)* | 92.134.242.73    | 3600 |
| CNAME | www       | obyw.one.        | 3600 |

### maya.fit (landing page + API)

| Type  | Subdomain |      Target      | TTL  |
|-------|-----------|------------------|------|
| A     | *(empty)* | 92.134.242.73    | 3600 |
| CNAME | www       | maya.fit.        | 3600 |
| A     | api       | 92.134.242.73    | 3600 |

> `api.maya.fit` serves the Kuzzle backend (port 7512).

### Subdomains (services on VPS)

|    Subdomain    |   Service   |             Why            |
|-----------------|-------------|----------------------------|
| api.maya.fit    | Kuzzle      | Realtime WebSocket backend |
| api.obyw.one    | PocketBase  | Data API                   |
| umami.obyw.one  | Umami       | Analytics dashboard        |
| status.obyw.one | Uptime Kuma | Monitoring                 |

All point to `92.134.242.73` via A records.

## OVH Manager steps

1. Log in to [OVH Manager](https://www.ovh.com/manager/)
2. Go to **Web Cloud** → **Domain Names** → select domain
3. Click **DNS Zone** tab
4. Delete any old A records for `@` (GitHub IPs `185.199.x.x` or old server)
5. Delete any `www` TXT placeholder records (`"3|welcome"` etc.)
6. Click **Add an entry** → type **A** → leave subdomain empty → paste `92.134.242.73`
7. Add CNAME: subdomain `www` → target `<domain>.` (with trailing dot)
8. Add A record for `api` if needed
9. Save and wait 10-30 min for propagation

## Verify

```bash
# Check DNS propagation
dig obyw.one +short
# Should show: 92.134.242.73

dig maya.fit +short
# Should show: 92.134.242.73

# Check HTTPS (Caddy auto-provisions cert on first request)
curl -I https://obyw.one
# Should show: server: Caddy

curl -I https://maya.fit
# Should show: server: Caddy
```

## Adding a new domain

1. Buy domain on OVH
2. Add A record for `@` → `92.134.242.73`
3. Add CNAME for `www` → `<domain>.`
4. Create landing page in `landings/<domain-name>/index.html`
5. Add Caddy block in `deploy/Caddyfile`
6. Push to `main` → GitHub Actions deploys
7. Caddy auto-provisions HTTPS on first request (~30s)
