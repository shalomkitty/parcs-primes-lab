#!/usr/bin/env bash
# Execute on LOCAL WSL. Stop VMs (do not delete data/disks).
set -euo pipefail
MASTER='parcs-lab'
ZONE="${ZONE:-$(gcloud compute instances list --filter="name=${MASTER}" --format='value(zone.basename())')}"
[[ -n "$ZONE" && "$ZONE" != *$'\n'* ]] || { echo 'Set ZONE=YOUR_ZONE' >&2; exit 1; }

for NAME in parcs-worker1 parcs-worker2 parcs-worker3 parcs-worker4 "$MASTER"; do
  if gcloud compute instances describe "$NAME" --zone="$ZONE" >/dev/null 2>&1; then
    STATUS="$(gcloud compute instances describe "$NAME" --zone="$ZONE" --format='value(status)')"
    if [[ "$STATUS" != 'TERMINATED' ]]; then
      echo "Stopping ${NAME}..."
      gcloud compute instances stop "$NAME" --zone="$ZONE" --quiet
    fi
  fi
done

echo 'PARCS VMs stopped. Persistent disks may still incur charges.'
