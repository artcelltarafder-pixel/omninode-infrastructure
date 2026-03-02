#!/bin/bash

# =============================================================
# OmniNode — Resource Manager
# Detects system resources and generates optimised
# docker-compose.override.yml with container resource limits
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OVERRIDE_FILE="$ROOT_DIR/docker-compose.override.yml"

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─────────────────────────────────────────────
# DETECT SYSTEM RESOURCES
# ─────────────────────────────────────────────
detect_resources() {
  TOTAL_CPU=$(nproc)
  TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
  AVAIL_RAM_MB=$(free -m | awk '/^Mem:/{print $7}')
  TOTAL_RAM_GB=$(echo "scale=1; $TOTAL_RAM_MB / 1024" | bc)
  AVAIL_RAM_GB=$(echo "scale=1; $AVAIL_RAM_MB / 1024" | bc)
}

# ─────────────────────────────────────────────
# CALCULATE RECOMMENDATIONS
# ─────────────────────────────────────────────
calculate_recommendations() {
  if [ "$TOTAL_RAM_MB" -ge 16384 ]; then
    BTC_CPU="1.0";    BTC_MEM="2G";    BTC_MEM_RES="512M"
    ETH_CPU="4.0";    ETH_MEM="8G";    ETH_MEM_RES="2G"
    LH_CPU="2.0";     LH_MEM="4G";     LH_MEM_RES="1G"
    EXP_CPU="0.25";   EXP_MEM="256M";  EXP_MEM_RES="64M"
    PROM_CPU="1.0";   PROM_MEM="1G";   PROM_MEM_RES="256M"
    GRAF_CPU="0.5";   GRAF_MEM="512M"; GRAF_MEM_RES="128M"
    ALERT_CPU="0.25"; ALERT_MEM="256M";ALERT_MEM_RES="64M"
    PROFILE="High Performance (16GB+)"
  elif [ "$TOTAL_RAM_MB" -ge 8192 ]; then
    BTC_CPU="1.0";    BTC_MEM="1G";    BTC_MEM_RES="256M"
    ETH_CPU="2.0";    ETH_MEM="4G";    ETH_MEM_RES="1G"
    LH_CPU="1.0";     LH_MEM="2G";     LH_MEM_RES="512M"
    EXP_CPU="0.25";   EXP_MEM="128M";  EXP_MEM_RES="32M"
    PROM_CPU="0.5";   PROM_MEM="512M"; PROM_MEM_RES="128M"
    GRAF_CPU="0.5";   GRAF_MEM="256M"; GRAF_MEM_RES="64M"
    ALERT_CPU="0.1";  ALERT_MEM="128M";ALERT_MEM_RES="32M"
    PROFILE="Balanced (8GB)"
  elif [ "$TOTAL_RAM_MB" -ge 4096 ]; then
    BTC_CPU="0.5";    BTC_MEM="512M";  BTC_MEM_RES="128M"
    ETH_CPU="1.0";    ETH_MEM="2G";    ETH_MEM_RES="512M"
    LH_CPU="0.5";     LH_MEM="1G";     LH_MEM_RES="256M"
    EXP_CPU="0.1";    EXP_MEM="64M";   EXP_MEM_RES="16M"
    PROM_CPU="0.25";  PROM_MEM="256M"; PROM_MEM_RES="64M"
    GRAF_CPU="0.25";  GRAF_MEM="128M"; GRAF_MEM_RES="32M"
    ALERT_CPU="0.1";  ALERT_MEM="64M"; ALERT_MEM_RES="16M"
    PROFILE="Conservative (4GB)"
  else
    BTC_CPU="0.5";    BTC_MEM="384M";  BTC_MEM_RES="128M"
    ETH_CPU="1.0";    ETH_MEM="1G";    ETH_MEM_RES="256M"
    LH_CPU="0.5";     LH_MEM="512M";   LH_MEM_RES="128M"
    EXP_CPU="0.1";    EXP_MEM="64M";   EXP_MEM_RES="16M"
    PROM_CPU="0.1";   PROM_MEM="128M"; PROM_MEM_RES="32M"
    GRAF_CPU="0.1";   GRAF_MEM="128M"; GRAF_MEM_RES="32M"
    ALERT_CPU="0.1";  ALERT_MEM="64M"; ALERT_MEM_RES="16M"
    PROFILE="Minimal (under 4GB)"
  fi
}

# ─────────────────────────────────────────────
# CALCULATE TOTALS AND PERCENTAGES
# ─────────────────────────────────────────────
calculate_totals() {
  # Sum all CPU limits
  TOTAL_CPU_ALLOC=$(echo "$BTC_CPU + $ETH_CPU + $LH_CPU + $EXP_CPU + $PROM_CPU + $GRAF_CPU + $ALERT_CPU" | bc)

  # Convert all RAM limits to MB and sum
  mem_to_mb() {
    local val="$1"
    if [[ "$val" == *G ]]; then
      echo "${val%G} * 1024" | bc
    else
      echo "${val%M}"
    fi
  }

  BTC_MB=$(mem_to_mb "$BTC_MEM")
  ETH_MB=$(mem_to_mb "$ETH_MEM")
  LH_MB=$(mem_to_mb "$LH_MEM")
  EXP_MB=$(mem_to_mb "$EXP_MEM")
  PROM_MB=$(mem_to_mb "$PROM_MEM")
  GRAF_MB=$(mem_to_mb "$GRAF_MEM")
  ALERT_MB=$(mem_to_mb "$ALERT_MEM")

  TOTAL_RAM_ALLOC_MB=$(echo "$BTC_MB + $ETH_MB + $LH_MB + $EXP_MB + $PROM_MB + $GRAF_MB + $ALERT_MB" | bc)
  TOTAL_RAM_ALLOC_GB=$(echo "scale=1; $TOTAL_RAM_ALLOC_MB / 1024" | bc)

  # Percentages
  CPU_PCT=$(echo "scale=0; $TOTAL_CPU_ALLOC * 100 / $TOTAL_CPU" | bc)
  RAM_PCT=$(echo "scale=0; $TOTAL_RAM_ALLOC_MB * 100 / $TOTAL_RAM_MB" | bc)

  # Colour code percentages
  if [ "$CPU_PCT" -le 50 ]; then
    CPU_COLOR="$GREEN"
  elif [ "$CPU_PCT" -le 80 ]; then
    CPU_COLOR="$YELLOW"
  else
    CPU_COLOR="$RED"
  fi

  if [ "$RAM_PCT" -le 50 ]; then
    RAM_COLOR="$GREEN"
  elif [ "$RAM_PCT" -le 80 ]; then
    RAM_COLOR="$YELLOW"
  else
    RAM_COLOR="$RED"
  fi

  # Overall recommendation
  MAX_PCT=$(( CPU_PCT > RAM_PCT ? CPU_PCT : RAM_PCT ))
  if [ "$MAX_PCT" -le 50 ]; then
    RECOMMENDATION="${GREEN}✓ Healthy allocation — plenty of headroom remaining${NC}"
  elif [ "$MAX_PCT" -le 80 ]; then
    RECOMMENDATION="${YELLOW}⚠ Moderate allocation — monitor under full sync load${NC}"
  else
    RECOMMENDATION="${RED}✗ High allocation — may cause contention on this machine${NC}"
  fi
}

# ─────────────────────────────────────────────
# DISPLAY HEADER
# ─────────────────────────────────────────────
print_header() {
  echo ""
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}║          OmniNode — Resource Manager                     ║${NC}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${BOLD}── System Detected ───────────────────────────────────────────${NC}"
  echo -e "  CPU Cores     : ${BOLD}${TOTAL_CPU} cores${NC}"
  echo -e "  Total RAM     : ${BOLD}${TOTAL_RAM_GB} GB${NC}"
  echo -e "  Available RAM : ${BOLD}${AVAIL_RAM_GB} GB${NC}"
  echo -e "  Profile       : ${BOLD}${GREEN}${PROFILE}${NC}"
  echo ""
}

# ─────────────────────────────────────────────
# DISPLAY RECOMMENDATIONS TABLE
# ─────────────────────────────────────────────
print_recommendations() {
  echo -e "${BOLD}── Recommended Resource Allocation ───────────────────────────${NC}"
  printf "  %-28s %-10s %-10s %-10s\n" "Container" "CPU Limit" "RAM Limit" "RAM Reserve"
  echo -e "  ${DIM}──────────────────────────────────────────────────────────${NC}"
  printf "  %-28s %-10s %-10s %-10s\n" "omninode-bitcoin"          "$BTC_CPU"   "$BTC_MEM"   "$BTC_MEM_RES"
  printf "  %-28s %-10s %-10s %-10s\n" "omninode-ethereum"         "$ETH_CPU"   "$ETH_MEM"   "$ETH_MEM_RES"
  printf "  %-28s %-10s %-10s %-10s\n" "omninode-lighthouse"       "$LH_CPU"    "$LH_MEM"    "$LH_MEM_RES"
  printf "  %-28s %-10s %-10s %-10s\n" "omninode-bitcoin-exporter" "$EXP_CPU"   "$EXP_MEM"   "$EXP_MEM_RES"
  printf "  %-28s %-10s %-10s %-10s\n" "omninode-prometheus"       "$PROM_CPU"  "$PROM_MEM"  "$PROM_MEM_RES"
  printf "  %-28s %-10s %-10s %-10s\n" "omninode-grafana"          "$GRAF_CPU"  "$GRAF_MEM"  "$GRAF_MEM_RES"
  printf "  %-28s %-10s %-10s %-10s\n" "omninode-alertmanager"     "$ALERT_CPU" "$ALERT_MEM" "$ALERT_MEM_RES"
  echo -e "  ${DIM}──────────────────────────────────────────────────────────${NC}"
  printf "  %-28s ${BOLD}%-10s %-10s${NC}\n" "Total Allocated" "${TOTAL_CPU_ALLOC} CPU" "${TOTAL_RAM_ALLOC_GB}G RAM"
  printf "  %-28s %-10s %-10s\n" "Machine Total" "${TOTAL_CPU} cores" "${TOTAL_RAM_GB}G"
  printf "  %-28s ${CPU_COLOR}${BOLD}%-10s${NC} ${RAM_COLOR}${BOLD}%-10s${NC}\n" "Usage" "${CPU_PCT}% CPU" "${RAM_PCT}% RAM"
  echo ""
  echo -e "  ${BOLD}Recommendation:${NC} $(echo -e $RECOMMENDATION)"
  echo ""
}

# ─────────────────────────────────────────────
# MANUAL ADJUSTMENT
# ─────────────────────────────────────────────
manual_adjust() {
  echo -e "${BOLD}${YELLOW}── Manual Adjustment Mode ────────────────────────────────────${NC}"
  echo -e "${DIM}  Press Enter to accept recommendation. Type a value to override.${NC}"
  echo ""

  adjust_container() {
    local NAME="$1"
    local CPU_VAR="$2"
    local MEM_VAR="$3"
    local RES_VAR="$4"

    echo -e "  ${BOLD}${CYAN}$NAME${NC}"
    read -p "    CPU limit   [${!CPU_VAR}]: " input
    [ -n "$input" ] && eval "$CPU_VAR='$input'"
    read -p "    RAM limit   [${!MEM_VAR}]: " input
    [ -n "$input" ] && eval "$MEM_VAR='$input'"
    read -p "    RAM reserve [${!RES_VAR}]: " input
    [ -n "$input" ] && eval "$RES_VAR='$input'"
    echo ""
  }

  adjust_container "omninode-bitcoin"          BTC_CPU   BTC_MEM   BTC_MEM_RES
  adjust_container "omninode-ethereum"         ETH_CPU   ETH_MEM   ETH_MEM_RES
  adjust_container "omninode-lighthouse"       LH_CPU    LH_MEM    LH_MEM_RES
  adjust_container "omninode-bitcoin-exporter" EXP_CPU   EXP_MEM   EXP_MEM_RES
  adjust_container "omninode-prometheus"       PROM_CPU  PROM_MEM  PROM_MEM_RES
  adjust_container "omninode-grafana"          GRAF_CPU  GRAF_MEM  GRAF_MEM_RES
  adjust_container "omninode-alertmanager"     ALERT_CPU ALERT_MEM ALERT_MEM_RES

  # Recalculate totals after manual adjustment
  calculate_totals
}

# ─────────────────────────────────────────────
# WRITE OVERRIDE FILE
# ─────────────────────────────────────────────
write_override() {
  cat > "$OVERRIDE_FILE" << YAML
# =============================================================
# OmniNode — Docker Compose Resource Override
# Auto-generated by: ./omninode resources
# Profile: ${PROFILE}
# Generated: $(date)
# Machine: ${TOTAL_CPU} CPU cores, ${TOTAL_RAM_GB}GB RAM
# CPU Allocated: ${TOTAL_CPU_ALLOC} cores (${CPU_PCT}%)
# RAM Allocated: ${TOTAL_RAM_ALLOC_GB}G (${RAM_PCT}%)
# DO NOT EDIT MANUALLY — regenerate with: ./omninode resources
# =============================================================

services:

  bitcoin:
    deploy:
      resources:
        limits:
          cpus: '${BTC_CPU}'
          memory: ${BTC_MEM}
        reservations:
          cpus: '0.1'
          memory: ${BTC_MEM_RES}

  ethereum:
    deploy:
      resources:
        limits:
          cpus: '${ETH_CPU}'
          memory: ${ETH_MEM}
        reservations:
          cpus: '0.25'
          memory: ${ETH_MEM_RES}

  lighthouse:
    deploy:
      resources:
        limits:
          cpus: '${LH_CPU}'
          memory: ${LH_MEM}
        reservations:
          cpus: '0.1'
          memory: ${LH_MEM_RES}

  bitcoin-exporter:
    deploy:
      resources:
        limits:
          cpus: '${EXP_CPU}'
          memory: ${EXP_MEM}
        reservations:
          cpus: '0.05'
          memory: ${EXP_MEM_RES}

  prometheus:
    deploy:
      resources:
        limits:
          cpus: '${PROM_CPU}'
          memory: ${PROM_MEM}
        reservations:
          cpus: '0.05'
          memory: ${PROM_MEM_RES}

  grafana:
    deploy:
      resources:
        limits:
          cpus: '${GRAF_CPU}'
          memory: ${GRAF_MEM}
        reservations:
          cpus: '0.05'
          memory: ${GRAF_MEM_RES}

  alertmanager:
    deploy:
      resources:
        limits:
          cpus: '${ALERT_CPU}'
          memory: ${ALERT_MEM}
        reservations:
          cpus: '0.05'
          memory: ${ALERT_MEM_RES}
YAML

  echo -e "${GREEN}${BOLD}✓ Override file written: docker-compose.override.yml${NC}"
}

# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────
detect_resources
calculate_recommendations
calculate_totals
print_header
print_recommendations

echo -e "${BOLD}── What would you like to do? ────────────────────────────────${NC}"
echo -e "  ${BOLD}[Enter]${NC}  Accept recommendations and generate override"
echo -e "  ${BOLD}[M]${NC}      Manually adjust each container"
echo -e "  ${BOLD}[Q]${NC}      Quit without changes"
echo ""
read -p "  Your choice: " choice

case "${choice,,}" in
  m)
    echo ""
    manual_adjust
    print_recommendations
    read -p "  Confirm and write override? [Y/n]: " confirm
    if [[ "${confirm,,}" == "n" ]]; then
      echo -e "${YELLOW}  Cancelled — no changes made.${NC}"
      exit 0
    fi
    ;;
  q)
    echo -e "${YELLOW}  Cancelled — no changes made.${NC}"
    exit 0
    ;;
  *)
    ;;
esac

write_override

echo ""
echo -e "${BOLD}── Summary ───────────────────────────────────────────────────${NC}"
echo -e "  Profile       : ${BOLD}${PROFILE}${NC}"
echo -e "  CPU Allocated : ${CPU_COLOR}${BOLD}${TOTAL_CPU_ALLOC} cores (${CPU_PCT}%)${NC}"
echo -e "  RAM Allocated : ${RAM_COLOR}${BOLD}${TOTAL_RAM_ALLOC_GB}G (${RAM_PCT}%)${NC}"
echo -e "  File          : ${BOLD}docker-compose.override.yml${NC}"
echo -e "  Applied       : ${BOLD}automatically on next ./omninode start all${NC}"
echo ""

read -p "  Restart stack now to apply limits? [Y/n]: " restart
if [[ "${restart,,}" != "n" ]]; then
  echo ""
  "$SCRIPT_DIR/omninode.sh" restart all
fi

echo ""
echo -e "${GREEN}${BOLD}✓ Resource limits applied successfully${NC}"
echo ""
