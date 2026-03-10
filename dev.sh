#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# dev.sh — Local development environment for macOS
#
# Starts Kuzzle (Docker) + PocketBase (native binary) locally
# so you can develop iOS apps against a local backend.
#
# Usage:
#   ./dev.sh up        Start all services
#   ./dev.sh down      Stop all services
#   ./dev.sh status    Show what's running
#   ./dev.sh logs      Tail Kuzzle logs
#   ./dev.sh reset     Stop + delete all local data (fresh start)
#
# Prerequisites:
#   - Docker (Colima or Docker Desktop)
#   - PocketBase binary (auto-downloaded on first run)
#
# Ports:
#   Kuzzle:     http://localhost:7512
#   PocketBase: http://localhost:8091 (obyw)
#   Redis:      localhost:6379 (internal)
#   ES:         localhost:9200 (internal)
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEV_DIR="$HOME/.obyw-dev"
PB_VERSION="0.25.9"
ACTION="${1:-status}"

# ── Colors ───────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
DIM='\033[0;90m'
NC='\033[0m'

log()  { echo -e "${GREEN}▸${NC} $1"; }
warn() { echo -e "${YELLOW}▸${NC} $1"; }
err()  { echo -e "${RED}▸${NC} $1"; }

# ── Setup: ensure dev directory + PocketBase binary ──────────
setup_dev_dir() {
  mkdir -p "$DEV_DIR/pb-obyw/pb_data" "$DEV_DIR/pb-obyw/pb_migrations"

  # Copy migrations if available
  if [ -d "$SCRIPT_DIR/pb_migrations" ]; then
    cp -n "$SCRIPT_DIR/pb_migrations/"* "$DEV_DIR/pb-obyw/pb_migrations/" 2>/dev/null || true
  fi

  # Download PocketBase if missing
  if [ ! -f "$DEV_DIR/pocketbase" ]; then
    log "Downloading PocketBase v${PB_VERSION} for macOS..."
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64)  PB_ARCH="amd64" ;;
      arm64)   PB_ARCH="arm64" ;;
      *) err "Unsupported arch: $ARCH" && exit 1 ;;
    esac
    curl -fsSL "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_darwin_${PB_ARCH}.zip" -o /tmp/pb-dev.zip
    unzip -o /tmp/pb-dev.zip -d "$DEV_DIR" && rm /tmp/pb-dev.zip
    chmod +x "$DEV_DIR/pocketbase"
    log "PocketBase installed at $DEV_DIR/pocketbase"
  fi
}

# ── Kuzzle (Docker Compose) ─────────────────────────────────
kuzzle_up() {
  if ! docker info &>/dev/null; then
    err "Docker is not running. Start Colima or Docker Desktop first."
    exit 1
  fi
  log "Starting Kuzzle stack (ES + Redis + Kuzzle)..."
  docker compose -f "$SCRIPT_DIR/deploy/docker-compose.kuzzle.yml" up -d
}

kuzzle_down() {
  docker compose -f "$SCRIPT_DIR/deploy/docker-compose.kuzzle.yml" down 2>/dev/null || true
}

kuzzle_status() {
  if docker compose -f "$SCRIPT_DIR/deploy/docker-compose.kuzzle.yml" ps --status running 2>/dev/null | grep -q kuzzle; then
    echo -e "  Kuzzle:     ${GREEN}running${NC}  → http://localhost:7512"
  else
    echo -e "  Kuzzle:     ${RED}stopped${NC}"
  fi
}

# ── PocketBase (native) ─────────────────────────────────────
pb_up() {
  if pgrep -f "pocketbase serve.*8091" &>/dev/null; then
    warn "PocketBase already running on port 8091"
    return
  fi
  log "Starting PocketBase (obyw-dev) on port 8091..."
  "$DEV_DIR/pocketbase" serve \
    --http=127.0.0.1:8091 \
    --dir="$DEV_DIR/pb-obyw/pb_data" \
    --migrationsDir="$DEV_DIR/pb-obyw/pb_migrations" \
    &>/dev/null &
  echo $! > "$DEV_DIR/pb-obyw.pid"
  sleep 1
  if curl -sf http://localhost:8091/api/health &>/dev/null; then
    log "PocketBase ready → http://localhost:8091/_/"
  else
    warn "PocketBase started but health check failed. Check logs."
  fi
}

pb_down() {
  if [ -f "$DEV_DIR/pb-obyw.pid" ]; then
    kill "$(cat "$DEV_DIR/pb-obyw.pid")" 2>/dev/null || true
    rm "$DEV_DIR/pb-obyw.pid"
  fi
  pkill -f "pocketbase serve.*8091" 2>/dev/null || true
}

pb_status() {
  if pgrep -f "pocketbase serve.*8091" &>/dev/null; then
    echo -e "  PocketBase: ${GREEN}running${NC}  → http://localhost:8091/_/"
  else
    echo -e "  PocketBase: ${RED}stopped${NC}"
  fi
}

# ── Actions ──────────────────────────────────────────────────
case "$ACTION" in
  up)
    setup_dev_dir
    kuzzle_up
    pb_up
    echo ""
    log "All services started. Local endpoints:"
    echo "  Kuzzle:     http://localhost:7512"
    echo "  PocketBase: http://localhost:8091/_/"
    echo ""
    echo -e "${DIM}Stop with: ./dev.sh down${NC}"
    ;;

  down)
    log "Stopping all services..."
    pb_down
    kuzzle_down
    log "All services stopped."
    ;;

  status)
    echo ""
    echo "  Obyw.one — Local Dev Environment"
    echo "  ─────────────────────────────────"
    kuzzle_status
    pb_status
    echo ""
    ;;

  logs)
    docker compose -f "$SCRIPT_DIR/deploy/docker-compose.kuzzle.yml" logs -f kuzzle
    ;;

  reset)
    warn "This will delete all local dev data. Continue? [y/N]"
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      pb_down
      kuzzle_down
      rm -rf "$DEV_DIR/pb-obyw/pb_data"
      docker compose -f "$SCRIPT_DIR/deploy/docker-compose.kuzzle.yml" down -v 2>/dev/null || true
      log "All local data deleted. Run './dev.sh up' to start fresh."
    else
      log "Cancelled."
    fi
    ;;

  *)
    echo "Usage: $0 {up|down|status|logs|reset}"
    exit 1
    ;;
esac
