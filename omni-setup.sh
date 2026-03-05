#!/bin/bash
# =============================================================
# OmniNode Infrastructure Manager — Setup Script
# Download this single file and run: bash omni-setup.sh
# Everything else happens automatically from here.
# =============================================================

set -euo pipefail

# =============================================================
# COLOURS
# =============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

TOTAL_STEPS=16
CURRENT_STEP=0

# =============================================================
# HARDCODED CONFIG — AUTO MODE
# =============================================================
HARDCODED_REPO="https://github.com/artcelltarafder-pixel/omninode-infrastructure.git"
DEFAULT_INSTALL_DIR="$HOME/omninode-infrastructure"

# =============================================================
# HELPERS — SHARED
# =============================================================
pause() {
    if [ "$INTERACTIVE" = true ]; then
        echo ""
        echo -e "${DIM} Press Enter to continue...${NC}"
        read -r
    fi
}

step_header() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    if [ "$INTERACTIVE" = true ]; then
        echo ""
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${CYAN} STEP $CURRENT_STEP of $TOTAL_STEPS — $1${NC}"
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
    fi
}

success() {
    if [ "$INTERACTIVE" = true ]; then
        echo -e "  ${GREEN}✓${NC} $1"
    else
        echo -e "  ${GREEN}✓${NC} $1"
    fi
}

info() {
    if [ "$INTERACTIVE" = true ]; then
        echo -e "  ${BLUE}→${NC} $1"
    fi
}

warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

fail() {
    echo ""
    echo -e "  ${RED}✗ ERROR: $1${NC}"
    echo ""
    exit 1
}

# Auto mode phase headers
auto_phase() {
    echo ""
    echo -e "${BOLD}$1${NC}"
}

# Auto mode check item with dots
auto_check() {
    local LABEL="$1"
    local VALUE="${2:-}"
    if [ -n "$VALUE" ]; then
        printf "  ${GREEN}✓${NC} %-28s %s\n" "$LABEL" "$VALUE"
    else
        printf "  ${GREEN}✓${NC} %s\n" "$LABEL"
    fi
}

auto_warn() {
    printf "  ${YELLOW}⚠${NC} %s\n" "$1"
}

# Pull with live dots indicator
pull_image() {
    local IMAGE="$1"
    local LABEL="$2"
    printf "  ${BLUE}→${NC} Pulling %-30s" "$LABEL"
    docker pull "$IMAGE" > /dev/null 2>&1 &
    PULL_PID=$!
    while kill -0 $PULL_PID 2>/dev/null; do
        printf "."
        sleep 1
    done
    wait $PULL_PID
    printf " ${GREEN}done${NC}\n"
}

# =============================================================
# WELCOME BANNER + MODE SELECTION
# =============================================================
clear
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                                                          ║${NC}"
echo -e "${BOLD}${CYAN}║          ██████╗ ███╗   ███╗███╗   ██╗██╗               ║${NC}"
echo -e "${BOLD}${CYAN}║         ██╔═══██╗████╗ ████║████╗  ██║██║               ║${NC}"
echo -e "${BOLD}${CYAN}║         ██║   ██║██╔████╔██║██╔██╗ ██║██║               ║${NC}"
echo -e "${BOLD}${CYAN}║         ██║   ██║██║╚██╔╝██║██║╚██╗██║██║               ║${NC}"
echo -e "${BOLD}${CYAN}║         ╚██████╔╝██║ ╚═╝ ██║██║ ╚████║██║               ║${NC}"
echo -e "${BOLD}${CYAN}║          ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝               ║${NC}"
echo -e "${BOLD}${CYAN}║                                                          ║${NC}"
echo -e "${BOLD}${CYAN}║         OmniNode Infrastructure Manager                  ║${NC}"
echo -e "${BOLD}${CYAN}║         Bitcoin · Ethereum · Full Observability          ║${NC}"
echo -e "${BOLD}${CYAN}║                                                          ║${NC}"
echo -e "${BOLD}${CYAN}║         Automated Setup — v1.0                           ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${DIM}  This script will set up a complete multi-chain blockchain${NC}"
echo -e "${DIM}  node infrastructure on this machine.${NC}"
echo ""
echo -e "${BOLD}  Select setup mode:${NC}"
echo ""
echo -e "  ${BOLD}${GREEN}[A]${NC}  Automatic   — uses all defaults, runs without prompts"
echo -e "  ${BOLD}${CYAN}[B]${NC}  Interactive — step by step, you control the pace"
echo ""
echo -n "  Your choice [A/B]: "
read -r MODE_CHOICE

case "${MODE_CHOICE^^}" in
    A)
        INTERACTIVE=false
        INSTALL_DIR="$DEFAULT_INSTALL_DIR"
        REPO_URL="$HARDCODED_REPO"
        REPO_PATH=$(echo "$REPO_URL" | sed 's|https://github.com/||' | sed 's|\.git$||')
        DISCORD_URL="https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE"
        clear
        echo ""
        echo -e "${BOLD}${CYAN}OmniNode — Automatic Setup${NC}"
        echo -e "${DIM}─────────────────────────────────────────${NC}"
        echo -e "  Execution Mode:  ${BOLD}AUTOMATIC${NC}"
        echo -e "  Install Path:    ${BOLD}$INSTALL_DIR${NC}"
        echo -e "  Repository:      ${BOLD}$REPO_PATH${NC}"
        echo ""
        ;;
    B)
        INTERACTIVE=true
        echo ""
        echo -e "  ${CYAN}✓ Interactive mode selected${NC}"
        echo ""
        pause
        ;;
    *)
        fail "Invalid choice. Run setup again and select A or B."
        ;;
esac

# =============================================================
# STEP 1 — CHECK PREREQUISITES
# =============================================================
step_header "Checking Prerequisites"

if [ "$INTERACTIVE" = true ]; then
    echo -e "  ${DIM}Checking that required tools are installed on this machine.${NC}"
    echo -e "  ${DIM}OmniNode requires: Git, Docker, Docker Compose${NC}"
    echo ""
else
    auto_phase "Prerequisites"
fi

MISSING=0

if command -v git &>/dev/null; then
    GIT_VERSION=$(git --version | awk '{print $3}')
    if [ "$INTERACTIVE" = true ]; then
        success "Git installed — version $GIT_VERSION"
    else
        auto_check "Git" "$GIT_VERSION"
    fi
else
    warn "Git not found — install with: sudo apt install git"
    MISSING=$((MISSING + 1))
fi

if command -v docker &>/dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    if [ "$INTERACTIVE" = true ]; then
        success "Docker installed — version $DOCKER_VERSION"
    else
        auto_check "Docker" "$DOCKER_VERSION"
    fi
else
    warn "Docker not found — install from: https://docs.docker.com/engine/install/"
    MISSING=$((MISSING + 1))
fi

if docker compose version &>/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version | awk '{print $4}')
    if [ "$INTERACTIVE" = true ]; then
        success "Docker Compose installed — version $COMPOSE_VERSION"
    else
        auto_check "Docker Compose" "$COMPOSE_VERSION"
    fi
else
    warn "Docker Compose not found — install from: https://docs.docker.com/compose/install/"
    MISSING=$((MISSING + 1))
fi

if docker info &>/dev/null 2>&1; then
    if [ "$INTERACTIVE" = true ]; then
        success "Docker daemon is running"
    else
        auto_check "Docker daemon" "running"
    fi
else
    warn "Docker daemon not running — start with: sudo systemctl start docker"
    MISSING=$((MISSING + 1))
fi

if [ $MISSING -gt 0 ]; then
    fail "$MISSING prerequisite(s) missing. Install them and run setup again."
fi

if [ "$INTERACTIVE" = true ]; then
    echo ""
    success "All prerequisites satisfied"
fi

pause

# =============================================================
# STEP 2 — INSTALL DIRECTORY
# =============================================================
step_header "Install Directory"

if [ "$INTERACTIVE" = true ]; then
    echo -e "  ${DIM}Choose where OmniNode will be installed on this machine.${NC}"
    echo -e "  ${DIM}A new directory will be created at this path.${NC}"
    echo ""
    echo -e "  Default: ${BOLD}~/omninode-infrastructure${NC}"
    echo ""
    echo -n "  Install directory [press Enter for default]: "
    read -r INSTALL_DIR

    if [ -z "$INSTALL_DIR" ]; then
        INSTALL_DIR="$DEFAULT_INSTALL_DIR"
    fi

    INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"
    echo ""

    if [ -d "$INSTALL_DIR" ]; then
        warn "Directory already exists: $INSTALL_DIR"
        echo ""
        echo -n "  Continue and use existing directory? [y/N]: "
        read -r CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
            fail "Setup cancelled. Choose a different directory."
        fi
    else
        success "Install directory set: $INSTALL_DIR"
    fi
    pause
fi

# =============================================================
# STEP 3 — PORT AVAILABILITY CHECK
# =============================================================
step_header "Port Availability Check"

if [ "$INTERACTIVE" = true ]; then
    echo -e "  ${DIM}Checking all required ports are free before cloning${NC}"
    echo -e "  ${DIM}or starting anything. Fail fast if there are conflicts.${NC}"
    echo ""
else
    auto_phase "System Validation"
fi

PORTS=(
    "3000:Grafana"
    "9090:Prometheus"
    "9093:Alertmanager"
    "9094:Discord Proxy"
    "8332:Bitcoin RPC"
    "8333:Bitcoin P2P"
    "8545:Ethereum HTTP RPC"
    "8546:Ethereum WebSocket"
    "30303:Ethereum P2P"
    "5052:Lighthouse HTTP"
    "9000:Lighthouse P2P"
    "6060:Ethereum Metrics"
    "9332:Bitcoin Exporter"
)

PORT_CONFLICTS=0

for PORT_ENTRY in "${PORTS[@]}"; do
    PORT="${PORT_ENTRY%%:*}"
    NAME="${PORT_ENTRY##*:}"
    if ss -tuln 2>/dev/null | grep -q ":$PORT " || \
       netstat -tuln 2>/dev/null | grep -q ":$PORT "; then
        warn "Port $PORT IN USE — $NAME"
        PORT_CONFLICTS=$((PORT_CONFLICTS + 1))
    else
        if [ "$INTERACTIVE" = true ]; then
            success "Port $PORT free — $NAME"
        fi
    fi
done

if [ $PORT_CONFLICTS -gt 0 ]; then
    fail "$PORT_CONFLICTS port(s) already in use. Free them and run setup again."
fi

if [ "$INTERACTIVE" = true ]; then
    echo ""
    success "All ports available"
else
    auto_check "All ports free" "13 checked"
fi

pause

# =============================================================
# STEP 4 — GITHUB REPO URL
# =============================================================
step_header "GitHub Repository"

if [ "$INTERACTIVE" = true ]; then
    echo -e "  ${DIM}OmniNode will be cloned from your GitHub repository.${NC}"
    echo -e "  ${DIM}Paste the HTTPS URL of your repository below.${NC}"
    echo ""
    echo -e "  ${DIM}Example: https://github.com/username/omninode-infrastructure.git${NC}"
    echo ""
    echo -n "  GitHub repository URL: "
    read -r REPO_URL

    if [ -z "$REPO_URL" ]; then
        fail "Repository URL cannot be empty."
    fi

    REPO_PATH=$(echo "$REPO_URL" | sed 's|https://github.com/||' | sed 's|\.git$||')
    echo ""
    info "Repository: $REPO_PATH"
    pause
fi

# =============================================================
# STEP 5 — VERIFY REPO STRUCTURE
# =============================================================
step_header "Verifying Repository Structure"

if [ "$INTERACTIVE" = true ]; then
    echo -e "  ${DIM}Checking GitHub API to verify the repository exists${NC}"
    echo -e "  ${DIM}and contains the correct OmniNode project structure.${NC}"
    echo ""
    info "Contacting GitHub API..."
else
    auto_phase "Repository"
fi

API_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://api.github.com/repos/$REPO_PATH" 2>/dev/null)

if [ "$API_RESPONSE" = "200" ]; then
    if [ "$INTERACTIVE" = true ]; then
        success "Repository found on GitHub"
    fi
elif [ "$API_RESPONSE" = "404" ]; then
    fail "Repository not found. Check the URL and ensure the repo is public."
else
    warn "GitHub API returned status $API_RESPONSE — continuing"
fi

REQUIRED_FILES=(
    "docker-compose.yml"
    "omninode"
    "scripts/omninode.sh"
    "scripts/health-watch.sh"
    "monitoring/prometheus/prometheus.yml"
    "monitoring/alertmanager/alertmanager.yml"
)

STRUCTURE_OK=1

if [ "$INTERACTIVE" = true ]; then
    echo ""
    info "Checking repository structure..."
fi

for FILE in "${REQUIRED_FILES[@]}"; do
    FILE_CHECK=$(curl -s -o /dev/null -w "%{http_code}" \
        "https://api.github.com/repos/$REPO_PATH/contents/$FILE" 2>/dev/null)
    if [ "$FILE_CHECK" = "200" ]; then
        if [ "$INTERACTIVE" = true ]; then
            success "$FILE"
        fi
    else
        warn "$FILE — not found"
        STRUCTURE_OK=0
    fi
done

if [ $STRUCTURE_OK -eq 1 ]; then
    if [ "$INTERACTIVE" = true ]; then
        echo ""
        echo -e "  ${GREEN}${BOLD}✓ Project verified — OmniNode structure confirmed${NC}"
    else
        auto_check "Verified" "$REPO_PATH"
    fi
else
    if [ "$INTERACTIVE" = true ]; then
        warn "Some files not found."
        echo -n "  Continue anyway? [y/N]: "
        read -r CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
            fail "Setup cancelled."
        fi
    else
        auto_warn "Some files not found — continuing"
    fi
fi

pause

# =============================================================
# STEP 6 — CLONE REPOSITORY
# =============================================================
step_header "Cloning Repository"

if [ "$INTERACTIVE" = true ]; then
    echo -e "  ${DIM}Cloning OmniNode from GitHub into your install directory.${NC}"
    echo -e "  ${DIM}You may be prompted for your GitHub credentials.${NC}"
    echo ""
    info "Cloning into: $INSTALL_DIR"
    echo ""
fi

if [ -d "$INSTALL_DIR/.git" ]; then
    if [ "$INTERACTIVE" = true ]; then
        warn "Git repository already exists — pulling latest changes..."
        echo ""
    fi
    cd "$INSTALL_DIR"
    git pull > /dev/null 2>&1
    if [ "$INTERACTIVE" = true ]; then
        success "Repository updated"
    else
        auto_check "Cloned →" "$INSTALL_DIR"
    fi
else
    git clone "$REPO_URL" "$INSTALL_DIR" > /dev/null 2>&1
    cd "$INSTALL_DIR"
    if [ "$INTERACTIVE" = true ]; then
        echo ""
        success "Repository cloned to $INSTALL_DIR"
    else
        auto_check "Cloned →" "$INSTALL_DIR"
    fi
fi

pause

# =============================================================
# STEP 7 — FIX SCRIPT PERMISSIONS
# =============================================================
step_header "Setting Permissions"

if [ "$INTERACTIVE" = true ]; then
    echo -e "  ${DIM}Making all scripts executable and setting correct${NC}"
    echo -e "  ${DIM}permissions on data directories.${NC}"
    echo ""
fi

cd "$INSTALL_DIR"

chmod +x omninode
for SCRIPT in scripts/*.sh; do
    chmod +x "$SCRIPT"
done

mkdir -p docker/bitcoin/data docker/ethereum/data docker/lighthouse/data
chmod 755 docker/bitcoin/data docker/ethereum/data docker/lighthouse/data
mkdir -p logs backups

if [ "$INTERACTIVE" = true ]; then
    success "Script permissions set"
    success "Data directory permissions set"
    success "logs/ and backups/ created"
else
    auto_check "Permissions applied"
    auto_check "Directories created"
fi

pause

# =============================================================
# STEP 8 — GENERATE ENVIRONMENT FILE
# =============================================================
step_header "Generating Environment Configuration"

if [ "$INTERACTIVE" = true ]; then
    echo -e "  ${DIM}Creating your .env file — the single source of truth${NC}"
    echo -e "  ${DIM}for all credentials and port configuration.${NC}"
    echo ""

    if [ -f "$INSTALL_DIR/.env" ]; then
        warn ".env file already exists"
        echo -n "  Overwrite existing .env? [y/N]: "
        read -r CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
            info "Keeping existing .env file"
            pause
        fi
    fi

    echo ""
    echo -n "  Discord webhook URL for alerts (press Enter to skip): "
    read -r DISCORD_URL

    if [ -z "$DISCORD_URL" ]; then
        DISCORD_URL="https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE"
        warn "No Discord URL provided — update DISCORD_WEBHOOK_URL in .env later"
    else
        success "Discord webhook URL set"
    fi
else
    auto_phase "Environment"
fi

cat > "$INSTALL_DIR/.env" << EOF
# =============================================================
# OmniNode Environment Configuration
# Generated by omni-setup.sh on $(date '+%Y-%m-%d %H:%M:%S')
# =============================================================

# Bitcoin
BTC_RPC_USER=omninode_btc
BTC_RPC_PASS=OmniNode@2025!
BTC_RPC_PORT=8332
BTC_P2P_PORT=8333

# Ethereum
ETH_HTTP_PORT=8545
ETH_WS_PORT=8546
ETH_P2P_PORT=30303
ETH_METRICS_PORT=6060

# Lighthouse
LIGHTHOUSE_HTTP_PORT=5052
LIGHTHOUSE_P2P_PORT=9000

# Monitoring
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
GRAFANA_PASSWORD=OmniNode@2025!
ALERTMANAGER_PORT=9093

# Alerting
DISCORD_WEBHOOK_URL=$DISCORD_URL
EOF

if [ "$INTERACTIVE" = true ]; then
    echo ""
    success ".env file written"
else
    auto_check ".env created"
fi

# =============================================================
# STEP 9 — GENERATE JWT SECRET
# =============================================================
step_header "Generating Lighthouse JWT Secret"

if [ "$INTERACTIVE" = true ]; then
    echo -e "  ${DIM}Ethereum (Geth) and Lighthouse authenticate using a shared${NC}"
    echo -e "  ${DIM}JWT secret. This must exist before the stack starts.${NC}"
    echo ""
fi

JWT_PATH="$INSTALL_DIR/docker/lighthouse/data/jwtsecret"

if [ -f "$JWT_PATH" ]; then
    if [ "$INTERACTIVE" = true ]; then
        warn "JWT secret already exists — keeping existing"
        info "Location: $JWT_PATH"
    else
        auto_check "JWT secret" "existing"
    fi
else
    JWT_SECRET="0x$(openssl rand -hex 32)"
    echo "$JWT_SECRET" > "$JWT_PATH"
    chmod 600 "$JWT_PATH"

    if [ "$INTERACTIVE" = true ]; then
        success "JWT secret generated"
        echo -e "  ${DIM}  Secret: ${JWT_SECRET:0:18}...${NC}"
        success "Permissions set: 600"
    else
        auto_check "JWT secret generated" "32-byte"
    fi
fi

pause

# =============================================================
# STEP 10 — DATA DIRECTORIES (interactive only — auto already done in step 7)
# =============================================================
step_header "Creating Data Directories"

if [ "$INTERACTIVE" = true ]; then
    echo -e "  ${DIM}Creating directories for blockchain node data.${NC}"
    echo -e "  ${DIM}Raw blockchain data will sync here automatically.${NC}"
    echo ""

    DIRS=(
        "docker/bitcoin/data:Bitcoin Core blockchain data"
        "docker/ethereum/data:Ethereum Geth chaindata"
        "docker/lighthouse/data:Lighthouse beacon data"
        "backups:Automated backup storage"
        "logs:Container log exports"
    )

    for DIR_ENTRY in "${DIRS[@]}"; do
        DIR="${DIR_ENTRY%%:*}"
        DESC="${DIR_ENTRY##*:}"
        mkdir -p "$INSTALL_DIR/$DIR"
        chmod 755 "$INSTALL_DIR/$DIR"
        success "$DIR — $DESC"
    done

    pause
fi

# =============================================================
# STEP 11 — PULL DOCKER IMAGES
# =============================================================
step_header "Pulling Docker Images"

if [ "$INTERACTIVE" = true ]; then
    echo -e "  ${DIM}Downloading all container images from Docker Hub.${NC}"
    echo -e "  ${DIM}This may take several minutes depending on connection speed.${NC}"
    echo ""

    IMAGES=(
        "lncm/bitcoind:v25.0:Bitcoin Core"
        "ethereum/client-go:stable:Ethereum Geth"
        "sigp/lighthouse:latest:Lighthouse Beacon Client"
        "python:3.11-slim:Python — Exporter and Discord Bridge"
        "prom/prometheus:latest:Prometheus"
        "grafana/grafana:latest:Grafana"
        "prom/alertmanager:latest:Alertmanager"
    )

    for IMAGE_ENTRY in "${IMAGES[@]}"; do
        IMAGE=$(echo "$IMAGE_ENTRY" | cut -d: -f1,2)
        DESC=$(echo "$IMAGE_ENTRY" | cut -d: -f3)
        echo ""
        info "Pulling $IMAGE — $DESC"
        docker pull "$IMAGE"
        success "$DESC ready"
    done
else
    auto_phase "Docker Images"
    pull_image "lncm/bitcoind:v25.0"          "Bitcoin Core"
    pull_image "ethereum/client-go:stable"     "Ethereum Geth"
    pull_image "sigp/lighthouse:latest"        "Lighthouse"
    pull_image "python:3.11-slim"              "Python (exporter + bridge)"
    pull_image "prom/prometheus:latest"        "Prometheus"
    pull_image "grafana/grafana:latest"        "Grafana"
    pull_image "prom/alertmanager:latest"      "Alertmanager"
fi

pause

# =============================================================
# STEP 12 — RESOURCE MANAGER
# =============================================================
step_header "Hardware Detection & Resource Allocation"

if [ "$INTERACTIVE" = true ]; then
    echo -e "  ${DIM}Detecting hardware and calculating optimal resource limits${NC}"
    echo -e "  ${DIM}for each container. Generates docker-compose.override.yml.${NC}"
    echo ""
    echo -e "${YELLOW}  The resource manager will run now. Follow its prompts.${NC}"
    echo ""
    pause
    cd "$INSTALL_DIR"
    bash scripts/resource-manager.sh --no-restart
else
    auto_phase "Resource Allocation"
    cd "$INSTALL_DIR"

    # Run resource manager silently and capture profile info
    bash scripts/resource-manager.sh --no-restart <<< "" > /tmp/omninode_resource_output.txt 2>&1

    # Extract and display key values
    PROFILE=$(grep "Profile" /tmp/omninode_resource_output.txt | head -1 | awk -F': ' '{print $2}' || echo "Auto-detected")
    CPU_ALLOC=$(grep "CPU Allocated" /tmp/omninode_resource_output.txt | awk '{print $4, $5}' || echo "applied")
    RAM_ALLOC=$(grep "RAM Allocated" /tmp/omninode_resource_output.txt | awk '{print $4, $5}' || echo "applied")

    auto_check "Profile" "$PROFILE"
    auto_check "CPU" "$CPU_ALLOC"
    auto_check "RAM" "$RAM_ALLOC"
    auto_check "docker-compose.override.yml written"
fi

pause

# =============================================================
# STEP 13 — START THE STACK
# =============================================================
step_header "Starting OmniNode Stack"

if [ "$INTERACTIVE" = true ]; then
    echo -e "  ${DIM}Starting all 9 containers. Port availability will be${NC}"
    echo -e "  ${DIM}checked automatically before startup.${NC}"
    echo ""
    pause
else
    auto_phase "Startup"
fi

cd "$INSTALL_DIR"

if [ "$INTERACTIVE" = true ]; then
    ./omninode start all
else
    # Run start silently, just show container count
    ./omninode start all > /tmp/omninode_start_output.txt 2>&1
    CONTAINER_COUNT=$(docker ps --filter "name=omninode" --format '{{.Names}}' | wc -l)
    auto_check "All ports free"
    auto_check "$CONTAINER_COUNT containers started"
fi

pause

# =============================================================
# STEP 14 — HEALTH CHECK
# =============================================================
step_header "Running Health Checks"

if [ "$INTERACTIVE" = true ]; then
    echo -e "  ${DIM}Waiting 30 seconds for all containers to initialise${NC}"
    echo -e "  ${DIM}before running health checks.${NC}"
    echo ""

    for i in {30..1}; do
        echo -ne "  ${BLUE}Waiting: ${BOLD}$i${NC} seconds...\r"
        sleep 1
    done
    echo ""
    echo ""
    info "Running OmniNode health watchdog..."
    echo ""
    cd "$INSTALL_DIR"
    ./omninode health-watch || true
else
    auto_phase "Health"
    printf "  ${BLUE}→${NC} Waiting for containers to initialise"
    for i in {1..30}; do
        printf "."
        sleep 1
    done
    echo ""

    cd "$INSTALL_DIR"
    # Run health-watch silently and parse results
    ./omninode health-watch > /tmp/omninode_health_output.txt 2>&1 || true

    if grep -q "Bitcoin RPC responding" /tmp/omninode_health_output.txt; then
        auto_check "Bitcoin RPC responding"
    else
        auto_warn "Bitcoin RPC not yet responding — node may still be starting"
    fi

    if grep -q "Ethereum RPC responding" /tmp/omninode_health_output.txt; then
        PEERS=$(grep "Ethereum RPC responding" /tmp/omninode_health_output.txt | grep -o "peers: [0-9]*" || echo "peers: -")
        auto_check "Ethereum RPC responding" "$PEERS"
    else
        auto_warn "Ethereum RPC not yet responding"
    fi

    if grep -q "Lighthouse beacon responding" /tmp/omninode_health_output.txt; then
        auto_check "Lighthouse responding"
    else
        auto_warn "Lighthouse not yet responding"
    fi

    if grep -q "Disk space OK" /tmp/omninode_health_output.txt; then
        DISK=$(grep "Disk space OK" /tmp/omninode_health_output.txt | grep -o "[0-9]*% used.*free" || echo "OK")
        auto_check "Disk OK" "$DISK"
    fi
fi

pause

# =============================================================
# STEP 15 — GENERATE COMMANDS.MD
# =============================================================
step_header "Generating Master Command Reference"

if [ "$INTERACTIVE" = true ]; then
    echo -e "  ${DIM}Creating COMMANDS.md — your complete reference for every${NC}"
    echo -e "  ${DIM}OmniNode operation.${NC}"
    echo ""
fi

COMMANDS_DATE=$(date '+%Y-%m-%d %H:%M:%S')
COMMANDS_TZ=$(date '+%Z')
COMMANDS_HOST=$(hostname)

cat > "$INSTALL_DIR/COMMANDS.md" << 'COMMANDS_EOF'
# OmniNode — Master Command Reference
Generated by omni-setup.sh on COMMANDS_DATE_PLACEHOLDER COMMANDS_TZ_PLACEHOLDER
Machine: COMMANDS_HOST_PLACEHOLDER

---

## 1. QUICK START

```bash
cd ~/omninode-infrastructure
./omninode start all         # Start entire stack
./omninode stop all          # Stop entire stack (auto-exports logs)
./omninode status            # Show all container status
./omninode health            # Live RPC health checks
./omninode health-watch      # Independent health watchdog → Discord
./omninode logs-export       # Export all container logs to logs/
./omninode resources         # Hardware detection + resource limits
```

---

## 2. NODE COMMANDS

### Bitcoin
```bash
./omninode start bitcoin
./omninode stop bitcoin
./omninode logs bitcoin

docker exec omninode-bitcoin bitcoin-cli -rpcuser=omninode_btc -rpcpassword=OmniNode@2025! getblockcount
docker exec omninode-bitcoin bitcoin-cli -rpcuser=omninode_btc -rpcpassword=OmniNode@2025! getblockchaininfo
docker exec omninode-bitcoin bitcoin-cli -rpcuser=omninode_btc -rpcpassword=OmniNode@2025! getconnectioncount
```

### Ethereum
```bash
./omninode start ethereum
./omninode stop ethereum
./omninode logs ethereum

curl -s -X POST http://localhost:8545 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'
curl -s -X POST http://localhost:8545 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'
```

### Lighthouse
```bash
./omninode logs lighthouse

curl http://localhost:5052/eth/v1/node/syncing
curl http://localhost:5052/eth/v1/node/peer_count
curl http://localhost:5052/eth/v1/node/identity
```

---

## 3. MONITORING — GRAFANA

```
URL:      http://localhost:3000
Login:    admin / OmniNode@2025!
```

Dashboards auto-load on startup. Prometheus datasource auto-provisioned (UID: omninode-prometheus).

---

## 4. MONITORING — PROMETHEUS

```
URL: http://localhost:9090
```

```bash
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool
curl -s http://localhost:9090/api/v1/alerts | python3 -m json.tool
```

---

## 5. ALERTMANAGER & DISCORD ALERTS

```
URL: http://localhost:9093
```

```bash
curl -X POST http://localhost:9093/api/v2/alerts -H "Content-Type: application/json" -d '[{"labels":{"alertname":"TestAlert","severity":"critical"},"annotations":{"summary":"OmniNode test alert"}}]'
docker logs omninode-discord-proxy
docker restart omninode-alertmanager
```

---

## 6. HEALTH WATCHDOG

```bash
./omninode health-watch
```

Checks: all 9 containers, Bitcoin RPC, Ethereum RPC, Lighthouse API, disk space.
Sends Discord alert directly — bypasses Prometheus entirely.

---

## 7. BACKUP

```bash
./scripts/backup.sh
```

Backs up configs, node state, Grafana dashboards. Keeps last 7 backups.

---

## 8. LOG EXPORT

```bash
./omninode logs-export
./omninode stop all

ls logs/
cat logs/TIMESTAMP/bitcoin.log
grep "ERROR" logs/TIMESTAMP/ethereum.log
```

---

## 9. RESOURCE MANAGER

```bash
./omninode resources
```

Auto-detects CPU and RAM. Profiles: High Performance (16GB+), Balanced (8GB), Conservative (4GB), Minimal (<4GB).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INFRASTRUCTURE AS CODE — DOCKER WORLD ENDS ABOVE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

---

## 10. TERRAFORM — Infrastructure Provisioning

```bash
cd terraform
terraform init
terraform validate
terraform plan -var="do_token=dummy_token" -var="ssh_public_key=ssh-rsa AAAAB3NzaC1yc2E demo"
terraform apply
terraform destroy
```

Resources: Droplet, Firewall, SSH Key, Volume, Volume Attachment
Outputs: node_ip, grafana_url, prometheus_url, bitcoin_rpc_url, ethereum_rpc_url, ssh_command

---

## 11. ANSIBLE — Configuration Management

```bash
cat > ansible/inventory-local.ini << 'EOF'
[omninode]
localhost ansible_connection=local ansible_user=YOUR_USERNAME
EOF

ansible-playbook -i ansible/inventory-local.ini ansible/playbooks/setup.yml --check
ansible-playbook -i ansible/inventory.ini ansible/playbooks/setup.yml
```

Colours: ok (green) = idempotent, changed (yellow) = updated, failed (red) = error

---

## 12. TROUBLESHOOTING — QUICK REFERENCE

```bash
# Soft reset — restart single container
docker restart omninode-bitcoin
docker restart omninode-ethereum
docker restart omninode-prometheus

# Hard reset — full stack
./omninode stop all
docker system prune -f
./omninode start all

# Check what a container is doing
docker logs omninode-bitcoin --tail 50
docker logs omninode-ethereum --tail 50
docker logs omninode-lighthouse --tail 50
docker logs omninode-discord-proxy --tail 50

# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool

# Check alert rules loaded
curl -s http://localhost:9090/api/v1/rules | python3 -m json.tool | grep name
```

---

## 13. FAILURE MODE GUIDE

---

### CONTAINER FAILURES

#### Container in restart loop
```bash
# Find the error
docker logs omninode-bitcoin --tail 30
docker logs omninode-ethereum --tail 30
docker logs omninode-lighthouse --tail 30

# Common causes:
# Bitcoin      → testnet config not under [test] section in bitcoin.conf
# Ethereum     → invalid flag (--gcmode light invalid, use snap)
# Lighthouse   → JWT secret missing or path wrong
# Alertmanager → env var not expanded in YAML — hardcode the value
```

#### Container exited unexpectedly
```bash
# Check exit code
docker inspect omninode-bitcoin | grep -A5 '"State"'

# Exit code 137 = OOM killed — increase RAM limit
./omninode resources

# Exit code 1 = application error — check logs
docker logs omninode-bitcoin --tail 50
```

#### Container stuck starting / unhealthy
```bash
# Check healthcheck status
docker inspect omninode-bitcoin | grep -A10 '"Health"'

# Force restart
docker restart omninode-bitcoin

# Stop and remove — let compose recreate
docker stop omninode-bitcoin
docker rm omninode-bitcoin
./omninode start bitcoin
```

---

### NODE FAILURES

#### Bitcoin RPC not responding
```bash
# Test RPC directly
docker exec omninode-bitcoin bitcoin-cli \
  -rpcuser=omninode_btc -rpcpassword=OmniNode@2025! getblockcount

# Common causes:
# - Node still starting (wait 60-120 seconds)
# - Wrong credentials in .env
# - testnet config not under [test] section in bitcoin.conf

cat docker/bitcoin/bitcoin.conf
```

#### Ethereum peers = 0
```bash
# Check peer count
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'

# Common causes:
# - Firewall blocking port 30303
# - Node still starting
# - Wrong network flag — must be --sepolia

docker logs omninode-ethereum --tail 30 | grep -i peer
```

#### Lighthouse not syncing
```bash
curl http://localhost:5052/eth/v1/node/syncing
curl http://localhost:5052/eth/v1/node/peer_count

# Common causes:
# - JWT secret mismatch between Geth and Lighthouse
# - Geth not ready yet
# - Checkpoint sync URL unreachable

# Verify JWT secret
cat docker/lighthouse/data/jwtsecret

# Regenerate JWT secret
openssl rand -hex 32 | sed 's/^/0x/' > docker/lighthouse/data/jwtsecret
chmod 600 docker/lighthouse/data/jwtsecret
docker restart omninode-ethereum omninode-lighthouse
```

#### Sync stalled — block height not increasing
```bash
# Bitcoin block height
docker exec omninode-bitcoin bitcoin-cli \
  -rpcuser=omninode_btc -rpcpassword=OmniNode@2025! getblockchaininfo | grep blocks

# Ethereum chain head
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Check peer count — low peers = slow sync
docker exec omninode-bitcoin bitcoin-cli \
  -rpcuser=omninode_btc -rpcpassword=OmniNode@2025! getconnectioncount

# Restart the stalled node
docker restart omninode-bitcoin
docker restart omninode-ethereum
```

---

### MONITORING FAILURES

#### Grafana showing No Data
```bash
# Most common cause — datasource UID mismatch
# Required UID: omninode-prometheus

# Check current datasource
curl -s http://admin:OmniNode@2025!@localhost:3000/api/datasources

# Verify provisioning file
cat monitoring/grafana/provisioning/datasources/prometheus.yml

# Restart Grafana to re-provision
docker restart omninode-grafana

# Check Prometheus is healthy
curl -s http://localhost:9090/-/healthy
```

#### Prometheus targets showing DOWN
```bash
# Check all targets
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep -A5 health

# Common causes:
# - Container name mismatch in prometheus.yml
# - Port mismatch
# - Container not running

docker restart omninode-prometheus
```

#### Discord alerts not firing
```bash
# Check bridge is running
docker ps | grep discord-proxy
docker logs omninode-discord-proxy --tail 20

# Check webhook URL
grep DISCORD_WEBHOOK_URL .env

# Test bridge directly
curl -X POST http://localhost:9094 \
  -H "Content-Type: application/json" \
  -d '{"alerts":[{"labels":{"alertname":"ManualTest","severity":"critical"},"annotations":{"summary":"Direct test"}}]}'

# Restart alerting chain
docker restart omninode-alertmanager omninode-discord-proxy
```

#### Alertmanager config error
```bash
docker logs omninode-alertmanager --tail 20

docker exec omninode-alertmanager \
  amtool check-config /etc/alertmanager/alertmanager.yml

curl -s http://localhost:9093/api/v2/alerts | python3 -m json.tool
```

---

### INFRASTRUCTURE FAILURES

#### Docker out of disk space
```bash
df -h
docker system df

# Remove unused images (safe — does not affect running containers)
docker image prune -f

# Remove stopped containers and unused volumes
docker system prune -f

# Nuclear — remove everything not running
docker system prune -a -f

# Check which container uses most disk
docker ps -s --format "table {{.Names}}\t{{.Size}}"
```

#### Port conflict on restart
```bash
sudo lsof -i :3000
sudo lsof -i :9090

sudo kill -9 $(sudo lsof -t -i :3000)

# Or stop all containers first
docker stop $(docker ps -q)
./omninode start all
```

#### docker-compose.override.yml corrupt or missing
```bash
./omninode resources

# Or delete and start without limits
rm docker-compose.override.yml
./omninode start all
```

#### JWT secret missing after reinstall
```bash
openssl rand -hex 32 | sed 's/^/0x/' > docker/lighthouse/data/jwtsecret
chmod 600 docker/lighthouse/data/jwtsecret
docker restart omninode-ethereum omninode-lighthouse
```

---

### RECOVERY PROCEDURES

#### Soft reset — restart one container
```bash
docker restart omninode-<name>
```

#### Hard reset — full stack restart
```bash
./omninode stop all
./omninode start all
```

#### Config reset — regenerate environment
```bash
cp .env.example .env
# Edit .env with your credentials
openssl rand -hex 32 | sed 's/^/0x/' > docker/lighthouse/data/jwtsecret
chmod 600 docker/lighthouse/data/jwtsecret
./omninode resources
./omninode start all
```

#### Restore from backup
```bash
ls backups/

cp backups/TIMESTAMP/docker-compose.yml .
cp backups/TIMESTAMP/bitcoin.conf docker/bitcoin/bitcoin.conf
cp -r backups/TIMESTAMP/monitoring/ monitoring/

./omninode stop all
./omninode start all
```

#### Nuclear reset — completely fresh start
```bash
./omninode stop all
docker system prune -f
rm -f docker-compose.override.yml
rm -f .env
bash omni-setup.sh
```

---

*Generated by OmniNode omni-setup.sh*
COMMANDS_EOF

# Replace placeholders with actual values
sed -i "s|COMMANDS_DATE_PLACEHOLDER|${COMMANDS_DATE}|g" "$INSTALL_DIR/COMMANDS.md"
sed -i "s|COMMANDS_TZ_PLACEHOLDER|${COMMANDS_TZ}|g" "$INSTALL_DIR/COMMANDS.md"
sed -i "s|COMMANDS_HOST_PLACEHOLDER|${COMMANDS_HOST}|g" "$INSTALL_DIR/COMMANDS.md"


if [ "$INTERACTIVE" = true ]; then
    success "COMMANDS.md generated"
    info "Location: $INSTALL_DIR/COMMANDS.md"
else
    auto_check "COMMANDS.md generated"
fi

pause

# =============================================================
# STEP 16 — SUCCESS SCREEN
# =============================================================
step_header "Setup Complete"

if [ "$INTERACTIVE" = true ]; then
    echo ""
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║                                                          ║${NC}"
    echo -e "${BOLD}${GREEN}║         ✓  OMNINODE IS RUNNING                           ║${NC}"
    echo -e "${BOLD}${GREEN}║                                                          ║${NC}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}  Service Endpoints:${NC}"
    echo -e "  ${CYAN}Grafana        →  http://localhost:3000${NC}"
    echo -e "  ${CYAN}Prometheus     →  http://localhost:9090${NC}"
    echo -e "  ${CYAN}Alertmanager   →  http://localhost:9093${NC}"
    echo -e "  ${CYAN}Bitcoin RPC    →  http://localhost:8332${NC}"
    echo -e "  ${CYAN}Ethereum RPC   →  http://localhost:8545${NC}"
    echo -e "  ${CYAN}Ethereum WS    →  ws://localhost:8546${NC}"
    echo ""
    echo -e "${BOLD}  Credentials:${NC}"
    echo -e "  Grafana login  →  ${BOLD}admin / OmniNode@2025!${NC}"
    echo -e "  Bitcoin RPC    →  ${BOLD}omninode_btc / OmniNode@2025!${NC}"
    echo ""
    echo -e "${BOLD}  Grafana Setup:${NC}"
    echo -e "  1. Open ${CYAN}http://localhost:3000${NC}"
    echo -e "  2. Login with admin / OmniNode@2025!"
    echo -e "  3. Click ${BOLD}Dashboards → Browse${NC}"
    echo -e "  4. OmniNode dashboard is auto-loaded"
    echo -e "  5. Prometheus datasource is auto-provisioned"
    echo ""
    echo -e "${BOLD}  Install Location:${NC}  ${BLUE}$INSTALL_DIR${NC}"
    echo -e "${BOLD}  Command Reference:${NC} ${BLUE}$INSTALL_DIR/COMMANDS.md${NC}"
    echo ""
    echo -e "${BOLD}  Daily Commands:${NC}"
    echo -e "  ${GREEN}./omninode start all${NC}       Start the stack"
    echo -e "  ${YELLOW}./omninode stop all${NC}        Stop and export logs"
    echo -e "  ${CYAN}./omninode health-watch${NC}    Independent health check"
    echo -e "  ${CYAN}./omninode status${NC}          Container status"
    echo ""
    echo -e "${DIM}  Nodes are syncing in the background. Bitcoin and Ethereum${NC}"
    echo -e "${DIM}  will take time to reach full sync. This is normal.${NC}"
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  OmniNode setup complete. Welcome to the node.${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
else
    # Auto mode — Template B clean summary
    echo ""
    echo -e "${BOLD}${CYAN}OmniNode — Automatic Setup${NC}"
    echo -e "${DIM}─────────────────────────────────────────${NC}"
    echo ""
    echo -e "${BOLD}Setup Complete${NC}"
    echo -e "  ${GREEN}✓${NC} Status:          ${BOLD}RUNNING${NC}"
    echo -e "  ${GREEN}✓${NC} Install path:    ${BOLD}$INSTALL_DIR${NC}"
    echo ""
    echo -e "${BOLD}Services${NC}"
    printf "  %-14s %s\n" "Grafana"      "http://localhost:3000"
    printf "  %-14s %s\n" "Prometheus"   "http://localhost:9090"
    printf "  %-14s %s\n" "Alertmanager" "http://localhost:9093"
    printf "  %-14s %s\n" "Bitcoin RPC"  "http://localhost:8332"
    printf "  %-14s %s\n" "Ethereum RPC" "http://localhost:8545"
    echo ""
    echo -e "${BOLD}Credentials${NC}"
    printf "  %-14s %s\n" "Grafana"     "admin / OmniNode@2025!"
    printf "  %-14s %s\n" "Bitcoin RPC" "omninode_btc / OmniNode@2025!"
    echo ""
    echo -e "${DIM}  Update DISCORD_WEBHOOK_URL in .env to enable alerts.${NC}"
    echo -e "${DIM}  Nodes are syncing in background — this is normal.${NC}"
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  OmniNode setup complete. Welcome to the node.${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
fi
