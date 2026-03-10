#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# deploy.sh — Deploy to server with pre-backup
#
# Wraps rsync/restart into single commands. Always backs up
# before deploying migrations or config changes.
#
# Usage:
#   ./deploy.sh landing maya.fit       Deploy maya.fit landing page
#   ./deploy.sh landing obyw.one       Deploy obyw.one landing page
#   ./deploy.sh landing all            Deploy all landing pages
#   ./deploy.sh migrations obyw        Deploy PB migrations + restart
#   ./deploy.sh caddy                  Validate + deploy Caddyfile + reload
#   ./deploy.sh kuzzle                 Deploy Kuzzle compose + restart
#   ./deploy.sh all                    Deploy everything
#   ./deploy.sh backup                 Create backup only (no deploy)
#   ./deploy.sh status                 Health check all services
#
# Environment:
#   DEPLOY_HOST    Server hostname/IP (or set in .deploy.env)
#   DEPLOY_USER    SSH user (default: deploy)
#   DEPLOY_ENV     preprod|prod (default: prod)
#
# Config file: .deploy.env (optional, sourced automatically)
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACTION="${1:-status}"

# ── Colors ───────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
DIM='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}▸${NC} $1"; }
warn() { echo -e "${YELLOW}▸${NC} $1"; }
err()  { echo -e "${RED}▸${NC} $1" >&2; }
step() { echo -e "${BOLD}═══ $1${NC}"; }

# ── Load config ──────────────────────────────────────────────
if [ -f "$SCRIPT_DIR/.deploy.env" ]; then
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/.deploy.env"
fi

DEPLOY_HOST="${DEPLOY_HOST:-}"
DEPLOY_USER="${DEPLOY_USER:-deploy}"
DEPLOY_ENV="${DEPLOY_ENV:-prod}"

if [ -z "$DEPLOY_HOST" ] && [ "$ACTION" != "status-local" ]; then
  # Check if we're doing a local-only action
  if [[ "$ACTION" != "status" ]] || [ -z "$DEPLOY_HOST" ]; then
    if [ "$ACTION" != "status" ]; then
      err "DEPLOY_HOST not set. Create .deploy.env or export DEPLOY_HOST."
      echo ""
      echo "  echo 'DEPLOY_HOST=your-server-ip' > $SCRIPT_DIR/.deploy.env"
      echo "  echo 'DEPLOY_USER=deploy' >> $SCRIPT_DIR/.deploy.env"
      exit 1
    fi
  fi
fi

SSH_CMD="ssh ${DEPLOY_USER}@${DEPLOY_HOST}"
RSYNC_CMD="rsync -azP --delete"
BACKUP_DIR="/opt/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# ── Port mapping by environment ──────────────────────────────
pb_port() {
  local project="$1"
  case "${DEPLOY_ENV}-${project}" in
    prod-obyw)       echo 8091 ;;
    preprod-obyw)    echo 8191 ;;
    prod-wabisabi)   echo 8090 ;;
    preprod-wabisabi) echo 8190 ;;
    *) err "Unknown project: $project" && exit 1 ;;
  esac
}

# ── Backup ───────────────────────────────────────────────────
backup_pocketbase() {
  local project="${1:-obyw}"
  local port
  port=$(pb_port "$project")
  local service="pocketbase@${project}-${DEPLOY_ENV}"
  local inst_dir="/opt/pocketbase/instances/${project}/${DEPLOY_ENV}"

  step "Backup PocketBase: ${project}/${DEPLOY_ENV}"
  $SSH_CMD "sudo mkdir -p ${BACKUP_DIR}/pocketbase && \
    sudo tar czf ${BACKUP_DIR}/pocketbase/${project}-${DEPLOY_ENV}-${TIMESTAMP}.tar.gz \
      -C ${inst_dir} pb_data && \
    echo 'Backup: ${BACKUP_DIR}/pocketbase/${project}-${DEPLOY_ENV}-${TIMESTAMP}.tar.gz'"
  log "Backup complete"
}

backup_kuzzle() {
  step "Backup Kuzzle (Elasticsearch snapshot)"
  $SSH_CMD "sudo mkdir -p ${BACKUP_DIR}/kuzzle && \
    docker exec maya-elasticsearch curl -sf -XPUT 'localhost:9200/_snapshot/backup/${TIMESTAMP}?wait_for_completion=true' \
      -H 'Content-Type: application/json' 2>/dev/null && \
    echo 'ES snapshot: ${TIMESTAMP}'" || warn "ES snapshot failed (may not be configured yet)"
  log "Kuzzle backup attempted"
}

backup_all() {
  backup_pocketbase "obyw"
  backup_pocketbase "wabisabi"
  backup_kuzzle
}

# ── Deploy: Landing Pages ────────────────────────────────────
deploy_landing() {
  local site="${2:-}"
  if [ -z "$site" ]; then
    err "Usage: $0 landing <domain|all>"
    exit 1
  fi

  if [ "$site" = "all" ]; then
    for dir in "$SCRIPT_DIR/landings"/*/; do
      [ -d "$dir" ] || continue
      local domain
      domain=$(basename "$dir")
      deploy_single_landing "$domain"
    done
  else
    deploy_single_landing "$site"
  fi
}

deploy_single_landing() {
  local domain="$1"
  local src="$SCRIPT_DIR/landings/${domain}/"

  if [ ! -d "$src" ]; then
    err "Landing not found: $src"
    return 1
  fi

  step "Deploy landing: ${domain}"
  $RSYNC_CMD "$src" "${DEPLOY_USER}@${DEPLOY_HOST}:/srv/www/${domain}/"
  log "Deployed ${domain}"
}

# ── Deploy: PocketBase Migrations ────────────────────────────
deploy_migrations() {
  local project="${2:-obyw}"
  local port
  port=$(pb_port "$project")
  local service="pocketbase@${project}-${DEPLOY_ENV}"
  local inst_dir="/opt/pocketbase/instances/${project}/${DEPLOY_ENV}"

  step "Deploy migrations: ${project}/${DEPLOY_ENV}"

  # Pre-backup
  backup_pocketbase "$project"

  # Copy migrations
  $RSYNC_CMD "$SCRIPT_DIR/pb_migrations/" \
    "${DEPLOY_USER}@${DEPLOY_HOST}:${inst_dir}/pb_migrations/"

  # Restart to apply
  $SSH_CMD "sudo systemctl restart ${service}"
  sleep 2

  # Health check
  if $SSH_CMD "curl -sf http://localhost:${port}/api/health" &>/dev/null; then
    log "PocketBase ${project}/${DEPLOY_ENV} healthy on port ${port}"
  else
    err "Health check failed! Check: journalctl -u ${service} -n 20"
    return 1
  fi
}

# ── Deploy: Caddyfile ────────────────────────────────────────
deploy_caddy() {
  step "Deploy Caddyfile"

  # Validate locally first (if caddy is installed)
  if command -v caddy &>/dev/null; then
    log "Validating Caddyfile locally..."
    caddy validate --config "$SCRIPT_DIR/deploy/Caddyfile" 2>/dev/null || {
      err "Caddyfile validation failed locally. Fix before deploying."
      return 1
    }
  fi

  # Backup current config
  $SSH_CMD "sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.bak.${TIMESTAMP}" 2>/dev/null || true

  # Deploy
  scp "$SCRIPT_DIR/deploy/Caddyfile" "${DEPLOY_USER}@${DEPLOY_HOST}:/tmp/Caddyfile.new"
  $SSH_CMD "sudo mv /tmp/Caddyfile.new /etc/caddy/Caddyfile && \
    sudo caddy validate --config /etc/caddy/Caddyfile && \
    sudo systemctl reload caddy"

  log "Caddy reloaded"
}

# ── Deploy: Kuzzle ───────────────────────────────────────────
deploy_kuzzle() {
  step "Deploy Kuzzle"

  backup_kuzzle

  scp "$SCRIPT_DIR/deploy/docker-compose.kuzzle.yml" \
    "${DEPLOY_USER}@${DEPLOY_HOST}:/opt/kuzzle/docker-compose.yml"
  $SSH_CMD "cd /opt/kuzzle && docker compose up -d"

  sleep 5
  if $SSH_CMD "curl -sf http://localhost:7512/_healthCheck" &>/dev/null; then
    log "Kuzzle healthy"
  else
    warn "Kuzzle health check failed. May still be starting up."
  fi
}

# ── Deploy: Everything ───────────────────────────────────────
deploy_all() {
  step "Full deploy (${DEPLOY_ENV})"
  echo ""

  deploy_landing "" "all"
  deploy_caddy
  deploy_migrations "" "obyw"
  deploy_kuzzle

  echo ""
  log "Full deploy complete."
  do_status
}

# ── Status / Health Checks ───────────────────────────────────
do_status() {
  echo ""
  echo -e "  ${BOLD}Obyw.one — Server Status${NC} (${DEPLOY_ENV})"
  echo "  ──────────────────────────────"

  if [ -z "$DEPLOY_HOST" ]; then
    warn "DEPLOY_HOST not set. Can't check remote status."
    return
  fi

  check_url() {
    local name="$1" url="$2"
    if $SSH_CMD "curl -sf '$url'" &>/dev/null 2>&1; then
      echo -e "  ${name}: ${GREEN}healthy${NC}"
    else
      echo -e "  ${name}: ${RED}down${NC}"
    fi
  }

  check_url "Caddy        " "https://maya.fit"
  check_url "Kuzzle       " "http://localhost:7512/_healthCheck"
  check_url "PB obyw      " "http://localhost:$(pb_port obyw)/api/health"
  check_url "PB wabisabi  " "http://localhost:$(pb_port wabisabi)/api/health"
  check_url "Uptime Kuma  " "http://localhost:3001"
  check_url "Umami        " "http://localhost:3000"
  echo ""
}

# ── Rollback ─────────────────────────────────────────────────
rollback() {
  local project="${2:-obyw}"
  local port
  port=$(pb_port "$project")
  local service="pocketbase@${project}-${DEPLOY_ENV}"
  local inst_dir="/opt/pocketbase/instances/${project}/${DEPLOY_ENV}"

  step "Rollback PocketBase: ${project}/${DEPLOY_ENV}"

  # Find latest backup
  local latest
  latest=$($SSH_CMD "ls -t ${BACKUP_DIR}/pocketbase/${project}-${DEPLOY_ENV}-*.tar.gz 2>/dev/null | head -1")

  if [ -z "$latest" ]; then
    err "No backup found for ${project}/${DEPLOY_ENV}"
    return 1
  fi

  warn "Restore from: $latest"
  warn "This will replace current data. Continue? [y/N]"
  read -r confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log "Cancelled."
    return
  fi

  $SSH_CMD "sudo systemctl stop ${service} && \
    sudo rm -rf ${inst_dir}/pb_data && \
    sudo mkdir -p ${inst_dir}/pb_data && \
    sudo tar xzf ${latest} -C ${inst_dir} && \
    sudo chown -R pocketbase:pocketbase ${inst_dir} && \
    sudo systemctl start ${service}"

  sleep 2
  if $SSH_CMD "curl -sf http://localhost:${port}/api/health" &>/dev/null; then
    log "Rollback successful. Service healthy."
  else
    err "Rollback done but health check failed. Check logs."
  fi
}

# ── Route action ─────────────────────────────────────────────
case "$ACTION" in
  landing)    deploy_landing "$@" ;;
  migrations) deploy_migrations "$@" ;;
  caddy)      deploy_caddy ;;
  kuzzle)     deploy_kuzzle ;;
  all)        deploy_all ;;
  backup)     backup_all ;;
  status)     do_status ;;
  rollback)   rollback "$@" ;;
  *)
    echo "Usage: $0 {landing <domain|all>|migrations <project>|caddy|kuzzle|all|backup|status|rollback <project>}"
    echo ""
    echo "Environment variables:"
    echo "  DEPLOY_HOST   Server hostname/IP"
    echo "  DEPLOY_USER   SSH user (default: deploy)"
    echo "  DEPLOY_ENV    preprod|prod (default: prod)"
    echo ""
    echo "Examples:"
    echo "  DEPLOY_ENV=preprod ./deploy.sh migrations obyw"
    echo "  ./deploy.sh landing maya.fit"
    echo "  ./deploy.sh rollback obyw"
    exit 1
    ;;
esac
