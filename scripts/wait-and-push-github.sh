#!/usr/bin/env bash
# Waits for GitHub repo to exist, then pushes main.
set -euo pipefail
cd "$(dirname "$0")/.."

REMOTE="git@github.com:hwq992689548/video-download-ev1.git"
MAX_ATTEMPTS=60
INTERVAL=30

echo "Waiting for $REMOTE ..."
for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  if git push -u origin main 2>/dev/null; then
    echo "Push succeeded on attempt $i"
    exit 0
  fi
  echo "Attempt $i/$MAX_ATTEMPTS failed (repo may not exist yet). Retry in ${INTERVAL}s..."
  sleep "$INTERVAL"
done

echo "Timed out. Create empty repo at:"
echo "  https://github.com/new?name=video-download-ev1"
echo "Then run: git push -u origin main"
exit 1
