#!/bin/bash
set -euxo pipefail
exec > /var/log/caller_setup.log 2>&1

# 1. System packages (jq is required by the iii installer)
apt-get update -y
apt-get install -y git curl wget unzip jq

# 2. Install Node.js 20.x (LTS)
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
node --version
npm --version

# 3. Install the iii CLI (RPC engine)
export HOME=/root
curl -fsSL https://install.iii.dev/iii/main/install.sh | sh
mv /root/.local/bin/iii* /usr/local/bin/ || true

# 4. Clone the project repo
REPO_DIR="/opt/alchemyst-assignment"
REPO_URL="https://github.com/tf-vishal/scalable-inference-architecture.git"

git clone "$REPO_URL" "$REPO_DIR"
chown -R ubuntu:ubuntu "$REPO_DIR"

# 5. Install TypeScript worker dependencies
WORKER_DIR="$REPO_DIR/workers/caller-worker"

sudo -u ubuntu bash -c "
  cd $WORKER_DIR
  npm install
"

# 6. Write iii engine config — this is the ONLY engine in the architecture.
#    Both caller-worker (local) and inference-worker (remote) connect to it.
CONFIG_DIR="/opt/alchemyst-assignment"
mkdir -p "$CONFIG_DIR/data"
chown -R ubuntu:ubuntu "$CONFIG_DIR/data"

cat > $CONFIG_DIR/config.yaml <<YAML
workers:
  - name: iii-observability
    config:
      enabled: true
      service_name: iii-caller
      exporter: memory
      memory_max_spans: 5000
      metrics_enabled: true
      metrics_exporter: memory
      logs_enabled: true
      logs_exporter: memory
      logs_console_output: true
      sampling_ratio: 1.0

  - name: iii-queue
    config:
      adapter:
        name: builtin

  - name: iii-state
    config:
      adapter:
        name: kv
        config:
          store_method: file_based
          file_path: $CONFIG_DIR/data/state_store.db

  - name: iii-http
    config:
      port: ${http_port}
      host: 0.0.0.0
      default_timeout: 120000
      concurrency_request_limit: 1024
      cors:
        allowed_origins:
          - '*'
        allowed_methods:
          - GET
          - POST
          - PUT
          - DELETE
          - OPTIONS

  - name: caller-worker
    worker_path: $WORKER_DIR

YAML

# 7. Systemd service for the iii engine on caller VM
cat > /etc/systemd/system/iii-engine.service <<SERVICE
[Unit]
Description=iii RPC Engine (Caller / API Gateway)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=$CONFIG_DIR
ExecStart=/usr/local/bin/iii --config config.yaml
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=iii-engine

[Install]
WantedBy=multi-user.target
SERVICE

# 8. Enable and start engine (caller-worker is managed by the engine via config)
systemctl daemon-reload
systemctl enable iii-engine
systemctl start iii-engine

echo "caller-worker setup done"
