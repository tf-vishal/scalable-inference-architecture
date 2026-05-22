#!/bin/bash
set -euxo pipefail
exec > /var/log/inference_setup.log 2>&1

# 1. System packages (jq is required by the iii installer)
apt-get update -y
apt-get install -y \
  python3 \
  python3-pip \
  python3-venv \
  git \
  curl \
  wget \
  unzip \
  jq

# 2. Clone the project repo
REPO_DIR="/opt/alchemyst-assignment"
REPO_URL="https://github.com/tf-vishal/scalable-inference-architecture.git"

git clone "$REPO_URL" "$REPO_DIR"
chown -R ubuntu:ubuntu "$REPO_DIR"

# 3. Set up Python virtualenv & install worker dependencies
WORKER_DIR="$REPO_DIR/workers/inference-worker"

sudo -u ubuntu bash -c "
  python3 -m venv $WORKER_DIR/venv
  source $WORKER_DIR/venv/bin/activate
  pip install --upgrade pip
  pip install -r $WORKER_DIR/requirements.txt
"

# 4. Create systemd service — inference-worker connects to the CALLER VM's engine
#    (Single-engine architecture: no local iii-engine on this VM)
cat > /etc/systemd/system/inference-worker.service <<SERVICE
[Unit]
Description=iii Inference Worker (Python)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=$WORKER_DIR
Environment="III_URL=ws://${worker_private_ip}:${ws_port}"
ExecStart=$WORKER_DIR/venv/bin/python inference_worker.py
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=inference-worker

[Install]
WantedBy=multi-user.target
SERVICE

# 5. Enable and start the inference worker
systemctl daemon-reload
systemctl enable inference-worker
systemctl start inference-worker

echo "inference-worker setup complete"