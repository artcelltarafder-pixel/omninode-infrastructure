# OmniNode Infrastructure Manager

A simple operator toolkit for running Bitcoin and Ethereum nodes together on one machine, with built-in monitoring, alerting, and basic automated operations. The goal is reliability and visibility, not building a platform — just the tools an operator needs to keep nodes healthy.

---

## What It Does

- Runs Bitcoin Core (testnet) and Geth (Sepolia) together using Docker
- Adds Lighthouse as the Ethereum consensus layer (beacon client)
- Provides a CLI so an operator can start, stop, restart, and check health without touching Docker directly
- Collects metrics from all containers using Prometheus
- Shows sync progress, peer counts, and node status in a Grafana dashboard
- Routes alerts through Alertmanager to Discord using a small webhook bridge
- Detects available CPU/RAM and generates simple resource limits per container
- Backs up node state, configs, and dashboards (keeps last 7 copies)
- Exports container logs on shutdown (keeps last 10 sessions)
- Provisions a basic cloud server with Terraform (DigitalOcean)
- Configures a fresh machine end-to-end with Ansible (Docker, firewall, systemd)
- Includes Kubernetes manifests for future expansion (separate repo)

---

## CLI Overview

The CLI is designed so an operator can manage the entire stack without touching Docker or Compose directly. Each command wraps a real operational workflow: starting and stopping nodes, checking health, inspecting resources, exporting logs, and running backups. It behaves like a small SRE toolbelt — simple commands that map directly to day-to-day node operations.

---

## Why This Project Matters

Blockchain infrastructure roles want people who can run nodes, keep them healthy, and respond when something breaks. This project is built around that. The nodes run. The alerts fire. The dashboard shows live data. Everything that breaks gets logged. I built it to understand what it actually takes to operate a multi-chain environment.

---

## How I Built This

I'm a career changer from a factory and manufacturing background. No CS degree. No bootcamp.

I use AI (Claude) throughout development — as a learning tool, code reviewer, and debugging partner. Every terminal error went back to Claude. The decisions are mine — what to build, how to structure it, what broke, what I changed.

I made every architectural call: running testnet instead of mainnet (same software, faster sync for demos), building a custom Discord bridge instead of relying on third-party proxy images that had payload issues, choosing state snapshots for backups instead of raw chaindata. I validated everything by running it. If it's in this repo, it works.

---

## What I Learned

- Bitcoin Core config must have testnet settings under a `[test]` section header — options outside it are ignored on testnet, which caused a silent restart loop
- Geth's `--syncmode` only accepts `full` or `archive` — `snap` is the right choice, `light` was removed
- Lighthouse and Geth authenticate via a shared JWT secret — if they don't share the same file, Lighthouse won't sync
- Third-party Alertmanager-to-Discord images had payload formatting issues — a small Flask bridge solved it cleanly
- Prometheus uses container names in scrape config, not IP addresses — Docker's internal DNS handles resolution
- Grafana datasource UIDs must match exactly between the dashboard JSON and the provisioning config — a mismatch causes "No Data" with no obvious error message
- `docker-compose.override.yml` merges automatically with the base compose file — useful for injecting resource limits without touching the base config
- Ansible's `--check` flag runs the full playbook dry — the only expected failure is git clone, because the repo is private

---

## Post-Mortem

**Bug:** Bitcoin container restarting every 30 seconds with no useful error in the logs.

**Root cause:** The `bitcoin.conf` had RPC and port settings at the top level of the file. Bitcoin Core ignores top-level settings when running in testnet mode — they must be under a `[test]` section header.

**Broken config:**
```ini
rpcuser=omninode_btc
rpcpassword=OmniNode@2025!
rpcport=8332
rpcbind=0.0.0.0
```

**Fixed config:**
```ini
[test]
rpcuser=omninode_btc
rpcpassword=OmniNode@2025!
rpcport=8332
rpcbind=0.0.0.0
```

**Lesson:** Bitcoin Core's config file is section-aware. Mainnet settings go at the top level. Testnet settings go under `[test]`. Running `bitcoin-cli getblockchaininfo` after fixing it confirmed the node came up correctly.

---

## Running It

```bash
# Clone and enter
git clone https://github.com/artcelltarafder-pixel/omninode-infrastructure.git
cd omninode-infrastructure

# Run setup (interactive or automatic)
bash omni-setup.sh

# Or manually
cp .env.example .env
# Edit .env with your values
./omninode start all

# Check status
./omninode status
./omninode health

# Stop (auto-exports logs)
./omninode stop all

# Resource manager
./omninode resources

# Backup
./scripts/backup.sh

# Terraform dry run — no real token needed
cd terraform
terraform plan -var="do_token=dummy_token" -var="ssh_public_key=ssh-rsa AAAAB3NzaC1yc2E demo"

# Ansible dry run
ansible-playbook -i ansible/inventory-local.ini ansible/playbooks/setup.yml --check
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Blockchain Nodes | Bitcoin Core (lncm/bitcoind:v25.0), Geth (ethereum/client-go:stable) |
| Consensus Layer | Lighthouse (sigp/lighthouse:latest) |
| Containerisation | Docker + Docker Compose |
| Orchestration | Kubernetes (separate repo) |
| Infrastructure as Code | Terraform — DigitalOcean provider |
| Config Management | Ansible |
| Metrics | Prometheus + custom Bitcoin exporter |
| Dashboards | Grafana — auto-provisioned |
| Alerting | Alertmanager + custom Flask Discord bridge |
| CI/CD | GitHub Actions |
| Scripting | Bash + Python |

---

## Project Structure

Key folders:

- `scripts/` — all CLI logic, exporters, backup, health watch, Discord bridge
- `monitoring/` — Prometheus config, alert rules, Grafana provisioning and dashboards
- `terraform/` — DigitalOcean infrastructure definitions
- `ansible/` — server provisioning playbook

Full layout is in the architecture diagram.

---

## Roadmap

- Add mainnet configuration option alongside testnet
- Set up log aggregation across all containers into a single searchable output
- Add a health check endpoint that returns JSON — easier to query from external tools
- Automate JWT secret rotation and container restart in one command
- Add alert for disk usage above 80% on the data volumes

---

*Career changer from manufacturing. Learning in public. Building real things.*
