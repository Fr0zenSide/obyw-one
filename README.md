# Obyw.one

Design | Digital Agency — centralized infrastructure and landing pages for all projects.

## Structure

```
obyw-one/
├── deploy/                 ← Server infrastructure (Caddy, Kuzzle, PocketBase, monitoring)
├── landings/               ← Static landing pages per domain
│   ├── maya.fit/
│   ├── wabisabi.app/
│   └── obyw.one/
├── pb_migrations/          ← Shared PocketBase schema (waitlist, community, feedback)
├── index.html              ← obyw.one agency site
├── css/
├── js/
└── assets/
```

## Projects Served

| Project | Landing | API | Backend |
|---------|---------|-----|---------|
| **Maya.fit** | `maya.fit` | `api.maya.fit` | Kuzzle (Docker) |
| **WabiSabi** | `wabisabi.app` | `api.wabisabi.app` | PocketBase (native) |
| **Obyw.one** | `obyw.one` | `api.obyw.one` | PocketBase (native, shared) |

## Deployment

See [`deploy/README.md`](deploy/README.md) for full infrastructure documentation.

## Local Development

Open `index.html` in a browser for the agency site. No build step required.
