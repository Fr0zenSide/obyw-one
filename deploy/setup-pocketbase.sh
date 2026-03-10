#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# setup-pocketbase.sh — Multi-instance PocketBase setup
#
# Structure (nested by project/env):
#   /opt/pocketbase/pocketbase                        ← shared binary
#   /opt/pocketbase/instances/<project>/<env>/         ← per-instance data + migrations
#   /etc/systemd/system/pocketbase@.service            ← template service
#
# Usage:
#   sudo bash setup-pocketbase.sh                              # install binary + template
#   sudo bash setup-pocketbase.sh add obyw prod 8091           # add prod instance
#   sudo bash setup-pocketbase.sh add obyw preprod 8191        # add preprod instance
#   sudo bash setup-pocketbase.sh add wabisabi prod 8090       # add prod instance
#   sudo bash setup-pocketbase.sh add wabisabi preprod 8190    # add preprod instance
#   sudo bash setup-pocketbase.sh bootstrap                    # create all 4 instances
#
# Port convention:
#   80X0 = prod    (wabisabi=8090, obyw=8091)
#   81X0 = preprod  (wabisabi=8190, obyw=8191)
#
# Directory tree:
#   /opt/pocketbase/instances/
#   ├── wabisabi/
#   │   ├── prod/      (8090)
#   │   └── preprod/   (8190)
#   └── obyw/
#       ├── prod/      (8091)
#       └── preprod/   (8191)
#
# Manage:
#   systemctl start pocketbase@obyw-prod
#   systemctl status pocketbase@wabisabi-preprod
#   journalctl -u pocketbase@obyw-prod -f
# ─────────────────────────────────────────────────────────────
set -euo pipefail

PB_VERSION="0.25.9"
BASE_DIR="/opt/pocketbase"
ACTION="${1:-install}"

# ── Install: shared binary + template service ──────────────
install_base() {
  echo "=== PocketBase Multi-Instance Setup ==="

  # Create pocketbase user
  if ! id -u pocketbase &>/dev/null; then
    echo "Creating pocketbase system user..."
    useradd --system --no-create-home --shell /usr/sbin/nologin pocketbase
  fi

  mkdir -p "$BASE_DIR/instances"

  # Download binary
  if [ ! -f "$BASE_DIR/pocketbase" ]; then
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64)  PB_ARCH="amd64" ;;
      aarch64|arm64) PB_ARCH="arm64" ;;
      *) echo "Unsupported arch: $ARCH" && exit 1 ;;
    esac

    echo "Downloading PocketBase v${PB_VERSION} (linux_${PB_ARCH})..."
    curl -fsSL "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_${PB_ARCH}.zip" -o /tmp/pb.zip
    unzip -o /tmp/pb.zip -d "$BASE_DIR" && rm /tmp/pb.zip
    chmod +x "$BASE_DIR/pocketbase"
    echo "Binary installed: $BASE_DIR/pocketbase"
  else
    echo "Binary already present: $($BASE_DIR/pocketbase --version 2>/dev/null || echo 'unknown')"
  fi

  chown -R pocketbase:pocketbase "$BASE_DIR"

  # Install template systemd service
  # %i = full instance name (e.g. obyw-prod)
  # We use overrides per instance to point to the nested directory
  cat > /etc/systemd/system/pocketbase@.service << 'SERVICE'
[Unit]
Description=PocketBase (%i)
After=network.target

[Service]
Type=simple
User=pocketbase
Group=pocketbase
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

  systemctl daemon-reload

  echo ""
  echo "=== Base install complete ==="
  echo ""
  echo "Next: add instances with:"
  echo "  sudo bash $0 add <project> <env> <port>"
  echo ""
  echo "Examples:"
  echo "  sudo bash $0 add obyw prod 8091"
  echo "  sudo bash $0 add wabisabi preprod 8190"
  echo ""
  echo "Existing instances:"
  list_instances
}

# ── Add: create a new instance ─────────────────────────────
add_instance() {
  local PROJECT="${2:-}"
  local ENV="${3:-}"
  local PORT="${4:-}"

  if [ -z "$PROJECT" ] || [ -z "$ENV" ] || [ -z "$PORT" ]; then
    echo "Usage: $0 add <project> <env> <port>"
    echo "Example: $0 add obyw prod 8091"
    exit 1
  fi

  local INST_DIR="$BASE_DIR/instances/$PROJECT/$ENV"
  local SERVICE_NAME="pocketbase@${PROJECT}-${ENV}"

  if [ -d "$INST_DIR/pb_data" ]; then
    echo "Instance '$PROJECT/$ENV' already exists at $INST_DIR"
    echo "To reset: rm -rf $INST_DIR/pb_data && systemctl restart $SERVICE_NAME"
    exit 1
  fi

  echo "=== Creating instance: $PROJECT/$ENV (port $PORT) ==="

  mkdir -p "$INST_DIR/pb_data" "$INST_DIR/pb_migrations"
  chown -R pocketbase:pocketbase "$BASE_DIR/instances/$PROJECT"

  # Override to point to the nested project/env directory
  mkdir -p "/etc/systemd/system/${SERVICE_NAME}.service.d"
  cat > "/etc/systemd/system/${SERVICE_NAME}.service.d/override.conf" << EOF
[Unit]
Description=PocketBase ($PROJECT/$ENV on port $PORT)

[Service]
ExecStart=/opt/pocketbase/pocketbase serve --http=127.0.0.1:${PORT} --dir=${INST_DIR}/pb_data --migrationsDir=${INST_DIR}/pb_migrations
WorkingDirectory=${INST_DIR}
EOF

  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME"
  systemctl start "$SERVICE_NAME"

  echo ""
  echo "=== Instance '$PROJECT/$ENV' running ==="
  echo ""
  echo "  Port:       $PORT"
  echo "  Data:       $INST_DIR/pb_data/"
  echo "  Migrations: $INST_DIR/pb_migrations/"
  echo "  Service:    $SERVICE_NAME"
  echo "  Admin UI:   http://127.0.0.1:${PORT}/_/"
  echo ""
  echo "  Caddy config to add:"
  echo ""
  echo "    your-domain.example {"
  echo "        reverse_proxy localhost:${PORT}"
  echo "    }"
  echo ""
  echo "Commands:"
  echo "  systemctl status $SERVICE_NAME"
  echo "  systemctl restart $SERVICE_NAME"
  echo "  journalctl -u $SERVICE_NAME -f"
}

# ── Remove: stop and clean up an instance ──────────────────
remove_instance() {
  local PROJECT="${2:-}"
  local ENV="${3:-}"

  if [ -z "$PROJECT" ] || [ -z "$ENV" ]; then
    echo "Usage: $0 remove <project> <env>"
    echo "Example: $0 remove obyw tmp"
    exit 1
  fi

  local INST_DIR="$BASE_DIR/instances/$PROJECT/$ENV"
  local SERVICE_NAME="pocketbase@${PROJECT}-${ENV}"

  if [ ! -d "$INST_DIR" ]; then
    echo "Instance '$PROJECT/$ENV' not found at $INST_DIR"
    exit 1
  fi

  echo "=== Removing instance: $PROJECT/$ENV ==="

  systemctl stop "$SERVICE_NAME" 2>/dev/null || true
  systemctl disable "$SERVICE_NAME" 2>/dev/null || true
  rm -rf "/etc/systemd/system/${SERVICE_NAME}.service.d"
  systemctl daemon-reload

  echo "Service stopped and disabled."
  echo "Data still at: $INST_DIR"
  echo "To delete data: rm -rf $INST_DIR"
}

# ── List: show all instances ───────────────────────────────
list_instances() {
  echo "=== PocketBase Instances ==="
  echo ""
  local found=false
  for project_dir in "$BASE_DIR/instances"/*/; do
    [ -d "$project_dir" ] || continue
    local project=$(basename "$project_dir")
    for env_dir in "$project_dir"*/; do
      [ -d "$env_dir" ] || continue
      local env=$(basename "$env_dir")
      local service="pocketbase@${project}-${env}"
      local status=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
      echo "  $project/$env → $env_dir (status: $status)"
      found=true
    done
  done
  if [ "$found" = false ]; then
    echo "  (none)"
  fi
}

# ── Bootstrap: create all project instances ────────────────
bootstrap_all() {
  echo "=== Bootstrapping all PocketBase instances ==="
  echo ""

  install_base

  # WabiSabi
  if [ ! -d "$BASE_DIR/instances/wabisabi/prod/pb_data" ]; then
    add_instance "$0" "wabisabi" "prod" "8090"
  else
    echo "wabisabi/prod already exists, skipping"
  fi

  if [ ! -d "$BASE_DIR/instances/wabisabi/preprod/pb_data" ]; then
    add_instance "$0" "wabisabi" "preprod" "8190"
  else
    echo "wabisabi/preprod already exists, skipping"
  fi

  # OBYW
  if [ ! -d "$BASE_DIR/instances/obyw/prod/pb_data" ]; then
    add_instance "$0" "obyw" "prod" "8091"
  else
    echo "obyw/prod already exists, skipping"
  fi

  if [ ! -d "$BASE_DIR/instances/obyw/preprod/pb_data" ]; then
    add_instance "$0" "obyw" "preprod" "8191"
  else
    echo "obyw/preprod already exists, skipping"
  fi

  echo ""
  echo "=== All instances ready ==="
  echo ""
  echo "Caddy config to add:"
  echo ""
  echo "  # WabiSabi"
  echo "  api.wabisabi.app {"
  echo "      reverse_proxy localhost:8090"
  echo "  }"
  echo "  preprod-api.wabisabi.app {"
  echo "      reverse_proxy localhost:8190"
  echo "  }"
  echo ""
  echo "  # OBYW"
  echo "  api.obyw.one {"
  echo "      reverse_proxy localhost:8091"
  echo "  }"
  echo "  preprod-api.obyw.one {"
  echo "      reverse_proxy localhost:8191"
  echo "  }"
  echo ""

  list_instances
}

# ── Route action ───────────────────────────────────────────
case "$ACTION" in
  install)   install_base ;;
  add)       add_instance "$@" ;;
  remove)    remove_instance "$@" ;;
  list)      list_instances ;;
  bootstrap) bootstrap_all ;;
  *)
    echo "Usage: $0 {install|add <project> <env> <port>|remove <project> <env>|bootstrap|list}"
    exit 1
    ;;
esac
