#!/usr/bin/env bash
# Runs on each separate parcs-workerN Compute Engine VM.
set -euo pipefail

IMAGE='hummer12007/parcs-node:latest'
METADATA='http://metadata.google.internal/computeMetadata/v1/instance/attributes/master-ip'

if ! command -v curl >/dev/null 2>&1 || ! command -v docker >/dev/null 2>&1; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl docker.io
fi
systemctl enable --now docker

MASTER_IP="$(curl --fail --silent --show-error \
  -H 'Metadata-Flavor: Google' "$METADATA")"
[[ "$MASTER_IP" =~ ^[0-9.]+$ ]] || { echo 'Invalid master IP' >&2; exit 1; }

# Wait for the master to be reachable before registering the worker.
ready=0
for ((attempt=1; attempt<=120; attempt++)); do
  if timeout 2 bash -c "</dev/tcp/${MASTER_IP}/8080" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 5
done
[[ "$ready" == 1 ]] || { echo "Master ${MASTER_IP}:8080 unreachable" >&2; exit 1; }

docker rm -f parcs-worker >/dev/null 2>&1 || true
docker image inspect "$IMAGE" >/dev/null 2>&1 || docker pull "$IMAGE"

# Do not use Docker bridge addresses across VMs: --network host lets
# PARCS advertise the VM's private VPC IP and its dynamically chosen port.
docker run -d --name parcs-worker --network host \
  --restart unless-stopped \
  -e "PARCS_ARGS=worker ${MASTER_IP}" "$IMAGE"

echo "PARCS worker started; master=${MASTER_IP}:8080"
