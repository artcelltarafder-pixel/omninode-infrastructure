#!/bin/bash

# =============================================================
# OmniNode — Infrastructure Control Interface
# Usage: ./omninode.sh [command] [target]
# Commands: start | stop | restart | status | logs | health
# Targets:  all | bitcoin | ethereum | monitoring
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load env
if [ -f "$ROOT_DIR/.env" ]; then
  export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
else
  echo "❌ .env file not found. Copy .env.example to .env first."
  exit 1
fi

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Container names
BTC_CONTAINER="omninode-bitcoin"
ETH_CONTAINER="omninode-ethereum"
PROM_CONTAINER="omninode-prometheus"
GRAF_CONTAINER="omninode-grafana"
ALERT_CONTAINER="omninode-alertmanager"

LIGHTHOUSE_CONTAINER="omninode-lighthouse"
ALL_CONTAINERS=("$BTC_CONTAINER" "$ETH_CONTAINER" "$LIGHTHOUSE_CONTAINER" "$PROM_CONTAINER" "$GRAF_CONTAINER" "$ALERT_CONTAINER")
NODE_CONTAINERS=("$BTC_CONTAINER" "$ETH_CONTAINER")
MONITORING_CONTAINERS=("$PROM_CONTAINER" "$GRAF_CONTAINER" "$ALERT_CONTAINER")

# =============================================================
# HEADER
# =============================================================
print_header() {
  echo ""
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}║          OmniNode Infrastructure Manager         ║${NC}"
  echo -e "${BOLD}${CYAN}║      Bitcoin · Ethereum · Full Observability     ║${NC}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
}

# =============================================================
# USAGE
# =============================================================
print_usage() {
  echo -e "${BOLD}Usage:${NC} ./omninode.sh [command] [target]"
  echo ""
  echo -e "${BOLD}Commands:${NC}"
  echo -e "  ${GREEN}start${NC}      Start nodes and services"
  echo -e "  ${RED}stop${NC}       Stop nodes and services"
  echo -e "  ${YELLOW}restart${NC}    Restart nodes and services"
  echo -e "  ${CYAN}status${NC}     Show running status of all containers"
  echo -e "  ${CYAN}health${NC}     Run health checks on all nodes"
  echo -e "  ${BLUE}logs${NC}       Tail logs for a target"
  echo ""
  echo -e "${BOLD}Targets:${NC}"
  echo -e "  ${BOLD}all${NC}        All containers (default)"
  echo -e "  ${BOLD}bitcoin${NC}    Bitcoin node only"
  echo -e "  ${BOLD}ethereum${NC}   Ethereum node only"
  echo -e "  ${BOLD}monitoring${NC} Prometheus + Grafana + Alertmanager"
  echo ""
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  ./omninode.sh start all"
  echo -e "  ./omninode.sh stop bitcoin"
  echo -e "  ./omninode.sh status"
  echo -e "  ./omninode.sh logs ethereum"
  echo -e "  ./omninode.sh health"
  echo ""
}

# =============================================================
# HELPERS
# =============================================================
container_running() {
  docker ps --format '{{.Names}}' | grep -q "^$1$"
}

container_exists() {
  docker ps -a --format '{{.Names}}' | grep -q "^$1$"
}

# =============================================================
# START
# =============================================================
cmd_start() {
  local TARGET="${1:-all}"

  print_header
  echo -e "${BOLD}→ Running port availability check...${NC}"
  echo ""

  if ! "$SCRIPT_DIR/check-ports.sh"; then
    echo -e "${RED}Startup aborted. Resolve port conflicts first.${NC}"
    exit 1
  fi

  echo -e "${BOLD}→ Starting OmniNode — target: ${CYAN}$TARGET${NC}"
  echo ""

  case "$TARGET" in
    all)
      docker compose -f "$ROOT_DIR/docker-compose.yml" up -d
      ;;
    bitcoin)
      docker compose -f "$ROOT_DIR/docker-compose.yml" up -d bitcoin
      ;;
    ethereum)
      docker compose -f "$ROOT_DIR/docker-compose.yml" up -d ethereum
      ;;
    monitoring)
      docker compose -f "$ROOT_DIR/docker-compose.yml" up -d prometheus grafana alertmanager
      ;;
    *)
      echo -e "${RED}Unknown target: $TARGET${NC}"
      print_usage
      exit 1
      ;;
  esac

  echo ""
  echo -e "${GREEN}${BOLD}✓ OmniNode started — target: $TARGET${NC}"
  echo ""
  cmd_status
}

# =============================================================
# STOP
# =============================================================
cmd_stop() {
  local TARGET="${1:-all}"

  print_header
  echo -e "${BOLD}→ Stopping OmniNode — target: ${YELLOW}$TARGET${NC}"
  echo ""

  case "$TARGET" in
    all)
      docker compose -f "$ROOT_DIR/docker-compose.yml" down
      ;;
    bitcoin)
      docker compose -f "$ROOT_DIR/docker-compose.yml" stop bitcoin
      ;;
    ethereum)
      docker compose -f "$ROOT_DIR/docker-compose.yml" stop ethereum
      ;;
    monitoring)
      docker compose -f "$ROOT_DIR/docker-compose.yml" stop prometheus grafana alertmanager
      ;;
    *)
      echo -e "${RED}Unknown target: $TARGET${NC}"
      print_usage
      exit 1
      ;;
  esac

  echo ""
  echo -e "${YELLOW}${BOLD}✓ OmniNode stopped — target: $TARGET${NC}"
  echo ""
}

# =============================================================
# RESTART
# =============================================================
cmd_restart() {
  local TARGET="${1:-all}"
  cmd_stop "$TARGET"
  sleep 2
  cmd_start "$TARGET"
}

# =============================================================
# STATUS
# =============================================================
cmd_status() {
  echo -e "${BOLD}${CYAN}── Container Status ──────────────────────────────────${NC}"
  echo ""

  printf "  ${BOLD}%-30s %-12s %-20s${NC}\n" "CONTAINER" "STATUS" "UPTIME"
  echo "  ──────────────────────────────────────────────────────"

  for CONTAINER in "${ALL_CONTAINERS[@]}"; do
    if container_running "$CONTAINER"; then
      UPTIME=$(docker inspect --format='{{.State.StartedAt}}' "$CONTAINER" 2>/dev/null | xargs -I{} date -d {} +"%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
      printf "  ${GREEN}%-30s %-12s %-20s${NC}\n" "$CONTAINER" "RUNNING" "$UPTIME"
    elif container_exists "$CONTAINER"; then
      printf "  ${RED}%-30s %-12s${NC}\n" "$CONTAINER" "STOPPED"
    else
      printf "  ${YELLOW}%-30s %-12s${NC}\n" "$CONTAINER" "NOT CREATED"
    fi
  done

  echo ""
  echo -e "${BOLD}${CYAN}── Service Endpoints ─────────────────────────────────${NC}"
  echo ""
  echo -e "  Grafana        →  ${BLUE}http://localhost:${GRAFANA_PORT}${NC}"
  echo -e "  Prometheus     →  ${BLUE}http://localhost:${PROMETHEUS_PORT}${NC}"
  echo -e "  Alertmanager   →  ${BLUE}http://localhost:${ALERTMANAGER_PORT}${NC}"
  echo -e "  Bitcoin RPC    →  ${BLUE}http://localhost:${BTC_RPC_PORT}${NC}"
  echo -e "  Ethereum RPC   →  ${BLUE}http://localhost:${ETH_HTTP_PORT}${NC}"
  echo -e "  Ethereum WS    →  ${BLUE}ws://localhost:${ETH_WS_PORT}${NC}"
  echo ""
}

# =============================================================
# HEALTH
# =============================================================
cmd_health() {
  print_header
  echo -e "${BOLD}${CYAN}── Node Health Checks ────────────────────────────────${NC}"
  echo ""

  # Bitcoin health
  echo -e "${BOLD}Bitcoin Core:${NC}"
  if container_running "$BTC_CONTAINER"; then
    BTC_INFO=$(docker exec "$BTC_CONTAINER" bitcoin-cli \
      -rpcuser="$BTC_RPC_USER" \
      -rpcpassword="$BTC_RPC_PASS" \
      -rpcport="$BTC_RPC_PORT" \
      getblockchaininfo 2>/dev/null || echo "ERROR")

    if [ "$BTC_INFO" = "ERROR" ]; then
      echo -e "  ${RED}✗ RPC not responding — node may still be starting${NC}"
    else
      BTC_BLOCKS=$(echo "$BTC_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['blocks'])" 2>/dev/null || echo "?")
      BTC_HEADERS=$(echo "$BTC_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['headers'])" 2>/dev/null || echo "?")
      BTC_SYNC=$(echo "$BTC_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"{d['verificationprogress']*100:.2f}%\")" 2>/dev/null || echo "?")
      BTC_PEERS=$(docker exec "$BTC_CONTAINER" bitcoin-cli \
        -rpcuser="$BTC_RPC_USER" \
        -rpcpassword="$BTC_RPC_PASS" \
        getconnectioncount 2>/dev/null || echo "?")

      echo -e "  ${GREEN}✓ RPC responding${NC}"
      echo -e "  Blocks:     ${BOLD}$BTC_BLOCKS${NC} / Headers: ${BOLD}$BTC_HEADERS${NC}"
      echo -e "  Sync:       ${BOLD}$BTC_SYNC${NC}"
      echo -e "  Peers:      ${BOLD}$BTC_PEERS${NC}"
    fi
  else
    echo -e "  ${RED}✗ Container not running${NC}"
  fi

  echo ""

  # Ethereum health
  echo -e "${BOLD}Ethereum (Geth):${NC}"
  if container_running "$ETH_CONTAINER"; then
    ETH_SYNC=$(docker exec "$ETH_CONTAINER" wget -qO- \
      --post-data='{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
      --header='Content-Type: application/json' \
      "http://localhost:8545" 2>/dev/null || echo "ERROR")

    ETH_PEERS=$(docker exec "$ETH_CONTAINER" wget -qO- \
      --post-data='{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
      --header='Content-Type: application/json' \
      "http://localhost:8545" 2>/dev/null || echo "ERROR")

    if [ "$ETH_SYNC" = "ERROR" ]; then
      echo -e "  ${RED}✗ RPC not responding — node may still be starting${NC}"
    else
      PEER_HEX=$(echo "$ETH_PEERS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'])" 2>/dev/null || echo "0x0")
      PEER_COUNT=$(python3 -c "print(int('$PEER_HEX', 16))" 2>/dev/null || echo "?")
      IS_SYNCING=$(echo "$ETH_SYNC" | python3 -c "import sys,json; d=json.load(sys.stdin); print('No' if d['result']==False else 'Yes')" 2>/dev/null || echo "?")

      echo -e "  ${GREEN}✓ RPC responding${NC}"
      echo -e "  Syncing:    ${BOLD}$IS_SYNCING${NC}"
      echo -e "  Peers:      ${BOLD}$PEER_COUNT${NC}"
    fi
  else
    echo -e "  ${RED}✗ Container not running${NC}"
  fi

  echo ""
  echo -e "${BOLD}${CYAN}── Monitoring Stack ──────────────────────────────────${NC}"
  echo ""

  for CONTAINER in "${MONITORING_CONTAINERS[@]}"; do
    if container_running "$CONTAINER"; then
      echo -e "  ${GREEN}✓ RUNNING${NC}  $CONTAINER"
    else
      echo -e "  ${RED}✗ STOPPED${NC}  $CONTAINER"
    fi
  done
  echo ""
}

# =============================================================
# LOGS
# =============================================================
cmd_logs() {
  local TARGET="${1:-all}"

  case "$TARGET" in
    all)
      docker compose -f "$ROOT_DIR/docker-compose.yml" logs -f
      ;;
    bitcoin)
      docker logs -f "$BTC_CONTAINER"
      ;;
    ethereum)
      docker logs -f "$ETH_CONTAINER"
      ;;
    monitoring)
      docker compose -f "$ROOT_DIR/docker-compose.yml" logs -f prometheus grafana alertmanager
      ;;
    *)
      echo -e "${RED}Unknown target: $TARGET${NC}"
      print_usage
      exit 1
      ;;
  esac
}

# =============================================================
# ENTRYPOINT
# =============================================================
COMMAND="${1:-help}"
TARGET="${2:-all}"

case "$COMMAND" in
  start)    cmd_start "$TARGET" ;;
  stop)     cmd_stop "$TARGET" ;;
  restart)  cmd_restart "$TARGET" ;;
  status)   print_header; cmd_status ;;
  health)   cmd_health ;;
  logs)      cmd_logs "$TARGET" ;;
  resources) bash "$SCRIPT_DIR/resource-manager.sh" ;;
  help|--help|-h) print_header; print_usage ;;
  *)
    echo -e "${RED}Unknown command: $COMMAND${NC}"
    print_usage
    exit 1
    ;;
esac
