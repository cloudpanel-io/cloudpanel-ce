#!/usr/bin/env bash
# Utility for https://github.com/cloudpanel-io/cloudpanel-ce/issues/758
# Removes crontab spool files for users that no longer exist on the system.
set -euo pipefail

CRONTAB_SPOOL="/var/spool/cron/crontabs"

if [[ ! -d "$CRONTAB_SPOOL" ]]; then
  echo "No crontab spool directory at $CRONTAB_SPOOL"
  exit 0
fi

removed=0
kept=0

for crontab_file in "$CRONTAB_SPOOL"/*; do
  [[ -e "$crontab_file" ]] || continue

  username="$(basename "$crontab_file")"

  if id "$username" &>/dev/null; then
    kept=$((kept + 1))
    continue
  fi

  echo "Removing orphan crontab for deleted user: $username"
  rm -f "$crontab_file"
  removed=$((removed + 1))
done

echo "Done. Removed: $removed, kept: $kept"
