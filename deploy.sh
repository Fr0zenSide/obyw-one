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
#   ./deploy.sh garage                  Deploy Garage S3 + create buckets
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

# ── Deploy: Garage S3 ──────────────────────────────────────
GARAGE_VERSION="v1.0.1"
GARAGE_BIN="/usr/local/bin/garage"
GARAGE_DATA="/var/lib/garage"
GARAGE_CONFIG="/etc/garage.toml"

deploy_garage() {
  step "Deploy Garage S3"

  # Install binary if missing or wrong version
  $SSH_CMD "if ! ${GARAGE_BIN} --version 2>/dev/null | grep -q '${GARAGE_VERSION}'; then
    echo 'Installing Garage ${GARAGE_VERSION}...'
    curl -sfL https://garagehq.deuxfleurs.fr/_releases/${GARAGE_VERSION}/x86_64-unknown-linux-musl/garage \
      -o /tmp/garage && \
    sudo install -m 755 /tmp/garage ${GARAGE_BIN} && \
    rm /tmp/garage
  fi"
  log "Garage binary ready"

  # Deploy config
  scp "$SCRIPT_DIR/deploy/garage-prod.toml" \
    "${DEPLOY_USER}@${DEPLOY_HOST}:/tmp/garage.toml.new"
  $SSH_CMD "sudo mv /tmp/garage.toml.new ${GARAGE_CONFIG}"

  # Create data dirs
  $SSH_CMD "sudo mkdir -p ${GARAGE_DATA}/{data,meta} && \
    sudo chown -R garage:garage ${GARAGE_DATA}"

  # Create systemd service if missing
  $SSH_CMD "if [ ! -f /etc/systemd/system/garage.service ]; then
    sudo tee /etc/systemd/system/garage.service > /dev/null <<UNIT
[Unit]
Description=Garage S3-compatible object storage
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=garage
Group=garage
ExecStart=${GARAGE_BIN} server
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT
    sudo systemctl daemon-reload
    sudo systemctl enable garage
  fi"

  # Ensure garage user exists
  $SSH_CMD "id -u garage &>/dev/null || sudo useradd -r -s /usr/sbin/nologin garage"

  # Start / restart
  $SSH_CMD "sudo systemctl restart garage"
  sleep 3

  # Health check
  if $SSH_CMD "curl -sf http://localhost:3903/health" &>/dev/null; then
    log "Garage healthy"
  else
    err "Garage health check failed. Check: journalctl -u garage -n 20"
    return 1
  fi

  # Layout: assign single node
  local node_id
  node_id=$($SSH_CMD "${GARAGE_BIN} status 2>/dev/null | grep -oP '^[a-f0-9]+' | head -1")
  if [ -n "$node_id" ]; then
    $SSH_CMD "${GARAGE_BIN} layout assign ${node_id} -z dc1 -c 1G -t prod" 2>/dev/null || true
    $SSH_CMD "${GARAGE_BIN} layout apply --version 1" 2>/dev/null || true
    log "Layout applied for node ${node_id:0:8}..."
  else
    warn "Could not determine node ID. Run 'garage status' on VPS."
  fi

  # Create buckets (idempotent)
  for bucket in maya-photos wabisabi-photos; do
    $SSH_CMD "${GARAGE_BIN} bucket create ${bucket}" 2>/dev/null || true
    log "Bucket: ${bucket}"
  done

  # Create API key for PocketBase
  local existing_key
  existing_key=$($SSH_CMD "${GARAGE_BIN} key list 2>/dev/null | grep pocketbase" || true)
  if [ -z "$existing_key" ]; then
    $SSH_CMD "${GARAGE_BIN} key create pocketbase-media"
    # Grant read/write on both buckets
    for bucket in maya-photos wabisabi-photos; do
      $SSH_CMD "${GARAGE_BIN} bucket allow --read --write --key pocketbase-media ${bucket}"
    done
    log "API key 'pocketbase-media' created with bucket access"
    warn "Save the key output above — it won't be shown again."
  else
    log "API key 'pocketbase-media' already exists"
  fi

  log "Garage S3 deployment complete"
}

# ── Deploy: Everything ───────────────────────────────────────
deploy_all() {
  step "Full deploy (${DEPLOY_ENV})"
  echo ""

  deploy_landing "" "all"
  deploy_caddy
  deploy_migrations "" "obyw"
  deploy_kuzzle
  deploy_garage

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
  check_url "Garage S3    " "http://localhost:3903/health"
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
  garage)     deploy_garage ;;
  kuzzle)     deploy_kuzzle ;;
  all)        deploy_all ;;
  backup)     backup_all ;;
  status)     do_status ;;
  rollback)   rollback "$@" ;;
  *)
    echo "Usage: $0 {landing <domain|all>|migrations <project>|caddy|garage|kuzzle|all|backup|status|rollback <project>}"
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
