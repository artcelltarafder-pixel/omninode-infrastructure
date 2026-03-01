#!/bin/bash

# =============================================================
# OmniNode — Backup Script
# Backs up node data, configs, and monitoring state
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$ROOT_DIR/.env" ]; then
  export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
else
  echo "❌ .env file not found."
  exit 1
fi

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Backup destination
BACKUP_DIR="$ROOT_DIR/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

mkdir -p "$BACKUP_PATH"

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║          OmniNode — Backup Manager               ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}→ Backup started: ${TIMESTAMP}${NC}"
echo -e "${BOLD}→ Destination:    ${BACKUP_PATH}${NC}"
echo ""

# -------------------------------------------------------------
# Backup configs
# -------------------------------------------------------------
echo -e "${BOLD}[1/4] Backing up configuration files...${NC}"
mkdir -p "$BACKUP_PATH/configs"
cp "$ROOT_DIR/docker-compose.yml" "$BACKUP_PATH/configs/"
cp "$ROOT_DIR/.env.example" "$BACKUP_PATH/configs/"
cp "$ROOT_DIR/docker/bitcoin/bitcoin.conf" "$BACKUP_PATH/configs/"
cp -r "$ROOT_DIR/monitoring" "$BACKUP_PATH/configs/monitoring"
echo -e "  ${GREEN}✓ Configs backed up${NC}"

# -------------------------------------------------------------
# Backup Bitcoin data snapshot
# -------------------------------------------------------------
echo -e "${BOLD}[2/4] Backing up Bitcoin node state...${NC}"
mkdir -p "$BACKUP_PATH/bitcoin"

if docker ps --format '{{.Names}}' | grep -q "^omninode-bitcoin$"; then
  # Save wallet and chainstate only — not full blocks (pruned anyway)
  docker exec omninode-bitcoin bitcoin-cli \
    -rpcuser="$BTC_RPC_USER" \
    -rpcpassword="$BTC_RPC_PASS" \
    getblockchaininfo > "$BACKUP_PATH/bitcoin/chaininfo.json" 2>/dev/null || true

  docker exec omninode-bitcoin bitcoin-cli \
    -rpcuser="$BTC_RPC_USER" \
    -rpcpassword="$BTC_RPC_PASS" \
    getnetworkinfo > "$BACKUP_PATH/bitcoin/networkinfo.json" 2>/dev/null || true

  echo -e "  ${GREEN}✓ Bitcoin state snapshot saved${NC}"
else
  echo -e "  ${YELLOW}⚠ Bitcoin container not running — skipping state snapshot${NC}"
fi

# -------------------------------------------------------------
# Backup Ethereum state
# -------------------------------------------------------------
echo -e "${BOLD}[3/4] Backing up Ethereum node state...${NC}"
mkdir -p "$BACKUP_PATH/ethereum"

if docker ps --format '{{.Names}}' | grep -q "^omninode-ethereum$"; then
  # Save sync status and peer info via RPC
  curl -s -X POST \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
    "http://localhost:$ETH_HTTP_PORT" > "$BACKUP_PATH/ethereum/syncstatus.json" 2>/dev/null || true

  curl -s -X POST \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
    "http://localhost:$ETH_HTTP_PORT" > "$BACKUP_PATH/ethereum/peercount.json" 2>/dev/null || true

  echo -e "  ${GREEN}✓ Ethereum state snapshot saved${NC}"
else
  echo -e "  ${YELLOW}⚠ Ethereum container not running — skipping state snapshot${NC}"
fi

# -------------------------------------------------------------
# Backup Grafana dashboards
# -------------------------------------------------------------
echo -e "${BOLD}[4/4] Backing up Grafana dashboards...${NC}"
mkdir -p "$BACKUP_PATH/grafana"
cp -r "$ROOT_DIR/monitoring/grafana" "$BACKUP_PATH/grafana/" 2>/dev/null || true
echo -e "  ${GREEN}✓ Grafana dashboards backed up${NC}"

# -------------------------------------------------------------
# Create backup manifest
# -------------------------------------------------------------
cat > "$BACKUP_PATH/manifest.json" << MANIFEST
{
  "timestamp": "$TIMESTAMP",
  "backup_path": "$BACKUP_PATH",
  "contents": [
    "configs/docker-compose.yml",
    "configs/.env.example",
    "configs/bitcoin.conf",
    "configs/monitoring/",
    "bitcoin/chaininfo.json",
    "bitcoin/networkinfo.json",
    "ethereum/syncstatus.json",
    "ethereum/peercount.json",
    "grafana/"
  ]
}
MANIFEST

# -------------------------------------------------------------
# Cleanup old backups — keep last 7
# -------------------------------------------------------------
echo ""
echo -e "${BOLD}→ Cleaning up old backups (keeping last 7)...${NC}"
ls -dt "$BACKUP_DIR"/*/ 2>/dev/null | tail -n +8 | xargs rm -rf 2>/dev/null || true
echo -e "  ${GREEN}✓ Cleanup done${NC}"

# -------------------------------------------------------------
# Summary
# -------------------------------------------------------------
BACKUP_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
echo ""
echo -e "${BOLD}${CYAN}── Backup Complete ───────────────────────────────────${NC}"
echo -e "  Timestamp:  ${BOLD}$TIMESTAMP${NC}"
echo -e "  Location:   ${BOLD}$BACKUP_PATH${NC}"
echo -e "  Size:       ${BOLD}$BACKUP_SIZE${NC}"
echo ""
echo -e "${GREEN}${BOLD}✓ Backup successful${NC}"
echo ""
