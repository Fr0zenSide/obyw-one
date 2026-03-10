# DNS Setup — OVH → GitHub Pages

How to point OVH-managed domains to GitHub Pages for static landing pages.

## GitHub Pages IPs (A records)

```
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```

## Per-domain setup

### obyw.one (portfolio root)

| Type  | Subdomain | Target | TTL |
|-------|-----------|--------|-----|
| A     | *(empty)* | 185.199.108.153 | 3600 |
| A     | *(empty)* | 185.199.109.153 | 3600 |
| A     | *(empty)* | 185.199.110.153 | 3600 |
| A     | *(empty)* | 185.199.111.153 | 3600 |
| CNAME | www       | fr0zenside.github.io. | 3600 |

GitHub repo: `Fr0zenSide/obyw-one` — Pages enabled, custom domain `obyw.one`.

### maya.fit (option A: GitHub Pages)

Same 4 A records for `@`, plus:

| Type  | Subdomain | Target | TTL |
|-------|-----------|--------|-----|
| CNAME | www       | fr0zenside.github.io. | 3600 |
| A     | api       | *your-vps-ip* | 3600 |

> **Important**: `api.maya.fit` must stay on the VPS (Kuzzle backend).

### maya.fit (option B: keep on VPS)

If the landing page needs server-side features or you prefer Caddy:

| Type  | Subdomain | Target | TTL |
|-------|-----------|--------|-----|
| A     | *(empty)* | *your-vps-ip* | 3600 |
| A     | api       | *your-vps-ip* | 3600 |

### Subdomains that MUST stay on VPS

These serve APIs/services, not static pages:

| Subdomain | Service | Why |
|-----------|---------|-----|
| api.maya.fit | Kuzzle | Realtime WebSocket backend |
| api.obyw.one | PocketBase | Data API |
| umami.obyw.one | Umami | Analytics dashboard |
| status.obyw.one | Uptime Kuma | Monitoring |

For these, add A records pointing to your VPS IP.

## OVH Manager steps

1. Log in to [OVH Manager](https://www.ovh.com/manager/)
2. Go to **Web Cloud** → **Domain Names** → select domain
3. Click **DNS Zone** tab
4. Delete existing A records for `@` (if pointing to old server)
5. Click **Add an entry** → type **A** → leave subdomain empty → paste each GitHub IP
6. Repeat for all 4 IPs
7. Add CNAME: subdomain `www` → target `fr0zenside.github.io.` (with trailing dot)
8. Add A record for `api` → your VPS IP (if needed)
9. Save and wait 10-30 min for propagation

## Verify

```bash
# Check DNS propagation
dig obyw.one +short
# Should show 185.199.108-111.153

# Check GitHub Pages
curl -I https://obyw.one
# Should show: server: GitHub.com

# HTTPS auto-enables after DNS resolves (Let's Encrypt via GitHub)
```

## GitHub side

After DNS is set, verify in each repo:
1. Go to repo **Settings** → **Pages**
2. Custom domain should show as verified (green check)
3. "Enforce HTTPS" should be checked

If it shows "DNS check unsuccessful", wait longer or check for conflicting records.

## Adding a new domain

1. Buy domain on OVH
2. Add the 4 GitHub A records + www CNAME in DNS zone
3. Create GitHub repo or add folder to `portfolio` repo
4. Enable Pages, set custom domain
5. Wait for DNS + HTTPS propagation
