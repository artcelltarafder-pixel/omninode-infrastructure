#!/usr/bin/env python3

# =============================================================
# OmniNode — Bitcoin Prometheus Exporter
# Queries Bitcoin Core RPC and exposes metrics for Prometheus
# Runs as a sidecar — scrape at :9332/metrics
# =============================================================

import os
import time
import json
import requests
from http.server import HTTPServer, BaseHTTPRequestHandler
from requests.auth import HTTPBasicAuth

# Config from environment
BTC_RPC_HOST = os.getenv("BTC_RPC_HOST", "bitcoin")
BTC_RPC_PORT = os.getenv("BTC_RPC_PORT", "8332")
BTC_RPC_USER = os.getenv("BTC_RPC_USER", "omninode_btc")
BTC_RPC_PASS = os.getenv("BTC_RPC_PASS", "OmniNode@2025!")
EXPORTER_PORT = int(os.getenv("BTC_EXPORTER_PORT", "9332"))
RPC_URL = f"http://{BTC_RPC_HOST}:{BTC_RPC_PORT}"

def rpc_call(method, params=None):
    payload = {
        "jsonrpc": "1.0",
        "id": "omninode-exporter",
        "method": method,
        "params": params or []
    }
    try:
        response = requests.post(
            RPC_URL,
            json=payload,
            auth=HTTPBasicAuth(BTC_RPC_USER, BTC_RPC_PASS),
            timeout=10
        )
        return response.json().get("result")
    except Exception:
        return None

def collect_metrics():
    metrics = []

    # Blockchain info
    info = rpc_call("getblockchaininfo")
    if info:
        metrics.append(f'# HELP bitcoin_blocks Current block height')
        metrics.append(f'# TYPE bitcoin_blocks gauge')
        metrics.append(f'bitcoin_blocks {info.get("blocks", 0)}')

        metrics.append(f'# HELP bitcoin_headers Current header height')
        metrics.append(f'# TYPE bitcoin_headers gauge')
        metrics.append(f'bitcoin_headers {info.get("headers", 0)}')

        metrics.append(f'# HELP bitcoin_verification_progress Blockchain sync progress (0-1)')
        metrics.append(f'# TYPE bitcoin_verification_progress gauge')
        metrics.append(f'bitcoin_verification_progress {info.get("verificationprogress", 0)}')

        metrics.append(f'# HELP bitcoin_difficulty Current mining difficulty')
        metrics.append(f'# TYPE bitcoin_difficulty gauge')
        metrics.append(f'bitcoin_difficulty {info.get("difficulty", 0)}')

        pruned = 1 if info.get("pruned", False) else 0
        metrics.append(f'# HELP bitcoin_pruned Whether node is running in pruned mode')
        metrics.append(f'# TYPE bitcoin_pruned gauge')
        metrics.append(f'bitcoin_pruned {pruned}')

        metrics.append(f'# HELP bitcoin_up Bitcoin node RPC reachable')
        metrics.append(f'# TYPE bitcoin_up gauge')
        metrics.append(f'bitcoin_up 1')
    else:
        metrics.append(f'# HELP bitcoin_up Bitcoin node RPC reachable')
        metrics.append(f'# TYPE bitcoin_up gauge')
        metrics.append(f'bitcoin_up 0')
        return "\n".join(metrics)

    # Peer info
    peers = rpc_call("getconnectioncount")
    if peers is not None:
        metrics.append(f'# HELP bitcoin_peers Number of connected peers')
        metrics.append(f'# TYPE bitcoin_peers gauge')
        metrics.append(f'bitcoin_peers {peers}')

    # Mempool info
    mempool = rpc_call("getmempoolinfo")
    if mempool:
        metrics.append(f'# HELP bitcoin_mempool_size Number of transactions in mempool')
        metrics.append(f'# TYPE bitcoin_mempool_size gauge')
        metrics.append(f'bitcoin_mempool_size {mempool.get("size", 0)}')

        metrics.append(f'# HELP bitcoin_mempool_bytes Mempool size in bytes')
        metrics.append(f'# TYPE bitcoin_mempool_bytes gauge')
        metrics.append(f'bitcoin_mempool_bytes {mempool.get("bytes", 0)}')

    # Network info
    netinfo = rpc_call("getnetworkinfo")
    if netinfo:
        metrics.append(f'# HELP bitcoin_version Bitcoin Core version')
        metrics.append(f'# TYPE bitcoin_version gauge')
        metrics.append(f'bitcoin_version {netinfo.get("version", 0)}')

    return "\n".join(metrics)

class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            metrics = collect_metrics()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write(metrics.encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # Suppress default access logs

if __name__ == "__main__":
    print(f"[OmniNode] Bitcoin exporter starting on port {EXPORTER_PORT}")
    print(f"[OmniNode] Scraping Bitcoin RPC at {RPC_URL}")
    server = HTTPServer(("0.0.0.0", EXPORTER_PORT), MetricsHandler)
    print(f"[OmniNode] Metrics available at http://0.0.0.0:{EXPORTER_PORT}/metrics")
    server.serve_forever()
