#!/usr/bin/env bash
# Watch for small models done, then handover from bench-serial.sh to bench-xet-large.sh.
set -u
cd "$HOME" || exit 1
# Wait until qwen-image-2.1 done: summary has 3 model rows (qwen36, coder, image)
# or serial.log shows its delete line
while true; do
  if grep -q "qwen-image-2.1" ~/benchmark-results/summary.tsv 2>/dev/null; then
    echo "handover: small models done $(date -Is)" > ~/benchmark-results/xet-handover.log
    break
  fi
  sleep 60
done
# Give current loop a moment to finish cleanup after qwen-image, then stop it
sleep 30
OLD_PID=$(pgrep -f "bash ./bench-serial.sh" 2>/dev/null | head -1 || true)
if [ -n "$OLD_PID" ]; then
  echo "stopping bench-serial.sh PID $OLD_PID $(date -Is)" >> ~/benchmark-results/xet-handover.log
  kill "$OLD_PID" 2>/dev/null || true
  # also stop any child datapoint/setup for qwen-image edge case
  for pid in $(pgrep -f "datapoint.py" 2>/dev/null || true); do
    echo "killing datapoint $pid" >> ~/benchmark-results/xet-handover.log
    kill "$pid" 2>/dev/null || true
  done
  sleep 10
fi
cd "$HOME" || exit 1
nohup ./bench-xet-large.sh > ~/benchmark-results-xet.log 2>&1 &
echo "started bench-xet-large.sh PID $! $(date -Is)" >> ~/benchmark-results/xet-handover.log
