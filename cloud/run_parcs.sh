#!/usr/bin/env bash
# Execute on your LOCAL WSL computer, from the project root:
#   bash cloud/run_parcs.sh 1|2|4
# Reuses the existing parcs-lab VM as master, adds worker VMs as needed.
set -euo pipefail

COUNT="${1:-4}"
case "$COUNT" in 1|2|4) ;; *) echo 'Usage: bash cloud/run_parcs.sh 1|2|4' >&2; exit 2 ;; esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER='parcs-lab'
TAG='parcs-cluster'
RULE='parcs-cluster-internal-tcp'
WORKER_TYPE="${WORKER_TYPE:-e2-small}"

command -v gcloud >/dev/null || { echo 'Run this script in LOCAL WSL with gcloud installed.' >&2; exit 1; }

# Read the actual zone of the existing master unless overridden.
ZONE="${ZONE:-$(gcloud compute instances list \
  --filter="name=${MASTER}" --format='value(zone.basename())')}"
[[ -n "$ZONE" && "$ZONE" != '(unset)' && "$ZONE" != *$'\n'* ]] || {
  echo "Cannot determine ${MASTER} zone. Set ZONE=YOUR_ZONE or create parcs-lab first." >&2
  exit 1
}

gcloud compute instances describe "$MASTER" --zone="$ZONE" >/dev/null
MASTER_IP="$(gcloud compute instances describe "$MASTER" --zone="$ZONE" \
  --format='value(networkInterfaces[0].networkIP)')"
NETWORK_URL="$(gcloud compute instances describe "$MASTER" --zone="$ZONE" \
  --format='value(networkInterfaces[0].network)')"
SUBNET_URL="$(gcloud compute instances describe "$MASTER" --zone="$ZONE" \
  --format='value(networkInterfaces[0].subnetwork)')"
NETWORK="${NETWORK_URL##*/}"
SUBNET="${SUBNET_URL##*/}"
[[ -n "$MASTER_IP" && -n "$NETWORK" && -n "$SUBNET" ]] || {
  echo 'Could not determine master private IP / VPC / subnet.' >&2; exit 1;
}

printf 'Master: %s | zone: %s | VPC: %s | private IP: %s\n' \
  "$MASTER" "$ZONE" "$NETWORK" "$MASTER_IP"

# All cluster VMs can talk to one another over private VPC addresses.
# Dynamic worker HTTP/Pyro ports require all TCP ports BETWEEN these tagged VMs.
gcloud compute instances add-tags "$MASTER" --zone="$ZONE" --tags="$TAG" --quiet >/dev/null
if ! gcloud compute firewall-rules describe "$RULE" >/dev/null 2>&1; then
  gcloud compute firewall-rules create "$RULE" \
    --network="$NETWORK" --direction=INGRESS \
    --target-tags="$TAG" --source-tags="$TAG" \
    --allow=tcp --description='Private PARCS TCP within tagged VMs only' --quiet
else
  RULE_NETWORK="$(gcloud compute firewall-rules describe "$RULE" --format='value(network)')"
  [[ "${RULE_NETWORK##*/}" == "$NETWORK" ]] || {
    echo "Firewall rule ${RULE} exists in another VPC; verify it manually." >&2; exit 1;
  }
fi

# Stop all existing workers first so they will register again on the new master.
for i in {1..4}; do
  NAME="parcs-worker${i}"
  if gcloud compute instances describe "$NAME" --zone="$ZONE" >/dev/null 2>&1; then
    STATUS="$(gcloud compute instances describe "$NAME" --zone="$ZONE" --format='value(status)')"
    if [[ "$STATUS" != 'TERMINATED' ]]; then
      echo "Stopping ${NAME} (${STATUS})..."
      gcloud compute instances stop "$NAME" --zone="$ZONE" --quiet
    fi
  fi
done

# Apply master startup script to the EXISTING VM; do not create a sixth VM.
gcloud compute instances add-metadata "$MASTER" --zone="$ZONE" \
  --metadata-from-file="startup-script=${ROOT}/master-startup.sh" --quiet >/dev/null
MASTER_STATUS="$(gcloud compute instances describe "$MASTER" --zone="$ZONE" --format='value(status)')"
if [[ "$MASTER_STATUS" == 'TERMINATED' ]]; then
  echo "Starting ${MASTER} (startup-script runs automatically)..."
  gcloud compute instances start "$MASTER" --zone="$ZONE" --quiet
elif [[ "$MASTER_STATUS" == 'RUNNING' ]]; then
  # SSH to the master can be intermittent. Reboot through the Compute API
  # instead; the startup-script runs automatically on every VM boot.
  # This intentionally ends old PARCS jobs before a new experiment.
  echo "Restarting ${MASTER} via Compute Engine API (no SSH required)..."
  gcloud compute instances stop "$MASTER" --zone="$ZONE" --quiet
  gcloud compute instances start "$MASTER" --zone="$ZONE" --quiet
else
  echo "Master status is ${MASTER_STATUS}; retry once the VM reaches RUNNING or TERMINATED." >&2
  exit 1
fi

# Create dedicated VM workers; when starting existing ones, their startup
# scripts recreate Docker containers and register them with the master.
for ((i=1; i<=COUNT; i++)); do
  NAME="parcs-worker${i}"
  if gcloud compute instances describe "$NAME" --zone="$ZONE" >/dev/null 2>&1; then
    gcloud compute instances add-tags "$NAME" --zone="$ZONE" --tags="$TAG" --quiet >/dev/null
    gcloud compute instances add-metadata "$NAME" --zone="$ZONE" \
      --metadata="master-ip=${MASTER_IP}" \
      --metadata-from-file="startup-script=${ROOT}/worker-startup.sh" --quiet >/dev/null
    gcloud compute instances start "$NAME" --zone="$ZONE" --quiet
  else
    gcloud compute instances create "$NAME" \
      --zone="$ZONE" --machine-type="$WORKER_TYPE" \
      --subnet="$SUBNET" \
      --image-family=debian-12 --image-project=debian-cloud \
      --boot-disk-size=20GB --tags="$TAG" \
      --metadata="master-ip=${MASTER_IP}" \
      --metadata-from-file="startup-script=${ROOT}/worker-startup.sh" --quiet
  fi
done

cat <<EOF2

Requested ${COUNT} worker VM(s) + master VM (${MASTER}).
Confirm all active workers in PARCS -> Nodes BEFORE adding a new job.
VMs may still be installing Docker; check the startup logs if needed.

SSH tunnel (run in another LOCAL WSL terminal):
  gcloud compute ssh ${MASTER} --zone=${ZONE} -- -N -L 8080:127.0.0.1:8080
Browser: http://localhost:8080
Check VMs: gcloud compute instances list
Stop costs: bash cloud/stop_parcs.sh
EOF2
