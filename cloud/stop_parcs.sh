#!/usr/bin/env bash
set -euo pipefail
sudo docker rm -f parcs-master parcs-worker1 parcs-worker2 parcs-worker3 parcs-worker4 >/dev/null 2>&1 || true
echo "PARCS containers stopped."
