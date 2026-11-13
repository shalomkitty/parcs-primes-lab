#!/usr/bin/env bash
set -euo pipefail

WORKERS="${1:-1}"
if ! [[ "$WORKERS" =~ ^[124]$ ]]; then
  echo "Usage: bash run_parcs.sh 1|2|4" >&2
  exit 1
fi

IMAGE="hummer12007/parcs-node:latest"
sudo docker network inspect parcs-lab >/dev/null 2>&1 || sudo docker network create parcs-lab


sudo docker rm -f parcs-master parcs-worker1 parcs-worker2 parcs-worker3 parcs-worker4 >/dev/null 2>&1 || true
sudo docker run -d --name parcs-master --network parcs-lab \
  -p 127.0.0.1:8080:8080 -e PARCS_ARGS=master "$IMAGE" >/dev/null

for ((i=1; i<=WORKERS; i++)); do
  sudo docker run -d --name "parcs-worker$i" --network parcs-lab \
    -e PARCS_ARGS="worker parcs-master" "$IMAGE" >/dev/null
done

echo "PARCS started: 1 master + $WORKERS worker(s)."
echo "Check: sudo docker ps"
echo "After ~10-20 seconds: visit http://localhost:8080 through an SSH tunnel."
