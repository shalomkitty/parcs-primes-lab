#!/usr/bin/env bash
# Runs on the existing parcs-lab VM (the master).
set -euo pipefail

IMAGE='hummer12007/parcs-node:latest'

if ! command -v docker >/dev/null 2>&1; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io
fi
systemctl enable --now docker

# Remove containers left by the old single-VM deployment.
docker rm -f parcs-master parcs-worker1 parcs-worker2 parcs-worker3 parcs-worker4 \
  >/dev/null 2>&1 || true

# Host networking is necessary: workers live on OTHER virtual machines.
# The master must be reachable at parcs-lab's private VPC IP.
docker image inspect "$IMAGE" >/dev/null 2>&1 || docker pull "$IMAGE"
docker run -d --name parcs-master --network host \
  --restart unless-stopped \
  -e PARCS_ARGS=master "$IMAGE"

echo 'PARCS master started on TCP port 8080.'
