#!/usr/bin/env bash
# Serial colibri benchmark: download -> datapoint -> save -> delete weights.
# Runs detached on the host. One model at a time. Do not run two copies.
set -u
cd "$HOME/colibri" || exit 1
mkdir -p "$HOME/benchmark-results"

# model_id max_new
MODELS=(
  "qwen36-35b 128"
  "qwen3-coder-30b 128"
  "qwen-image-2.1 128"
  "deepseek-v4-flash-reap 64"
  "deepseek-v4-flash 32"
  "qwen38-flash-next 64"
  "mimo-v2.6-flash 32"
  "glm-5.3 32"
  "glm-5.2 32"
)

SUMMARY="$HOME/benchmark-results/summary.tsv"
printf "model_id\tdownload_gb\tprompt_tok_s\tdecode_tok_s\tcoli_version\tnotes\n" > "$SUMMARY"
COLI_VERSION=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)

for entry in "${MODELS[@]}"; do
  MODEL=$(echo "$entry" | cut -d' ' -f1)
  MAXNEW=$(echo "$entry" | cut -d' ' -f2)
  echo "=== [$MODEL] start $(date -Is) ===" | tee -a "$HOME/benchmark-results/serial.log"
  df -h "$HOME" | tail -1 >> "$HOME/benchmark-results/serial.log"
  free -h | head -2 >> "$HOME/benchmark-results/serial.log"

  # Setup (resume-safe: skips download if already present)
  # Wait for any existing setup process to finish first
  while pgrep -f "coli setup" >/dev/null 2>&1; do
    echo "waiting for existing coli setup to finish..." | tee -a "$HOME/benchmark-results/serial.log"
    sleep 30
  done
  python3 c/coli setup --yes --model "$MODEL" --no-start --no-gpu > "$HOME/benchmark-results/setup-$MODEL.log" 2>&1
  SETUP_RC=$?
  tail -n 20 "$HOME/benchmark-results/setup-$MODEL.log" >> "$HOME/benchmark-results/serial.log" 2>&1
  if [ $SETUP_RC -ne 0 ]; then
    echo "=== [$MODEL] SETUP FAILED rc=$SETUP_RC (see setup-$MODEL.log), continuing ===" | tee -a "$HOME/benchmark-results/serial.log"
    printf "%s\t-\t-\t-\t%s\tsetup_failed rc=%s\n" "$MODEL" "$COLI_VERSION" "$SETUP_RC" >> "$SUMMARY"
    python3 c/coli stop >/dev/null 2>&1 || true
    rm -rf "$HOME/colibri-models/$MODEL" 2>/dev/null || true
    continue
  fi

  MODEL_DIR="$HOME/colibri-models/$MODEL"
  # Download size in GB
  DL_GB=$(du -sb "$MODEL_DIR" 2>/dev/null | cut -f1 | awk '{printf "%.1f", $1/1e9}')
  echo "=== [$MODEL] downloaded ${DL_GB}GB, benchmarking (max-new=$MAXNEW) ===" | tee -a "$HOME/benchmark-results/serial.log"

  # Benchmark with colibri's standard datapoint. qwen-image is image-gen: datapoint is chat-only,
  # so record server start + one image generation timing instead.
  if [ "$MODEL" = "qwen-image-2.1" ]; then
    {
      echo "# $MODEL image benchmark $(date -Is)"
      echo "coli commit: $COLI_VERSION"
      echo "model_dir: $MODEL_DIR size ${DL_GB}GB"
      echo "method: coli start + timed POST /v1/images/generations (768x512)"
      echo "--- start ---"
      python3 c/coli stop >/dev/null 2>&1 || true
      python3 c/coli start --no-browser 2>&1 | head -n 20
      sleep 5
      echo "--- timed generation ---"
      START=$(date +%s)
      curl -s -X POST http://127.0.0.1:8000/v1/images/generations -H 'Content-Type: application/json' -d '{"prompt":"a red cube on a table","size":"768x512","n":1}' -o /tmp/qwenimg.out -w "http_code=%{http_code}\ntime_total=%{time_total}s\n" 2>&1 | tee -a -
      END=$(date +%s)
      echo "wall_seconds: $((END-START))" | tee -a -
      head -c 500 /tmp/qwenimg.out 2>/dev/null | tee -a -
      echo
      python3 c/coli stop 2>&1 | head -n 5
      echo "--- done ---"
    } > "$HOME/benchmark-results/datapoint-$MODEL.md" 2>&1
    # Summary: note image time
    IMG_TIME=$(grep -a "time_total" "$HOME/benchmark-results/datapoint-$MODEL.md" | head -1 || echo "see datapoint file")
    printf "qwen-image-2.1\t%s\t-\t-\t%s\timage_gen: %s (see datapoint-qwen-image-2.1.md)\n" "$DL_GB" "$COLI_VERSION" "$IMG_TIME" >> "$SUMMARY"
  else
    python3 c/tools/datapoint.py --mode persistent --snap "$MODEL_DIR" --max-new "$MAXNEW" --rotating-runs 4 \
      > "$HOME/benchmark-results/datapoint-$MODEL.md" 2> "$HOME/benchmark-results/datapoint-$MODEL.stderr.log"
    echo "=== [$MODEL] datapoint exit $? ===" | tee -a "$HOME/benchmark-results/serial.log"
    # Extract headline: rotating (primary) median tok/s from Workload summary table
    # (match the bold table row only, not the paragraph mentioning it)
    HEADLINE=$(grep -a "\*\*rotating prompts" "$HOME/benchmark-results/datapoint-$MODEL.md" | head -1 | awk -F'|' '{gsub(/ /,"",$4); print $4}')
    [ -z "$HEADLINE" ] && HEADLINE="-"
    printf "%s\t%s\t-\t%s\t%s\t%s\n" "$MODEL" "$DL_GB" "$HEADLINE" "$COLI_VERSION" "max-new=$MAXNEW; see datapoint-$MODEL.md" >> "$SUMMARY"
  fi

  python3 c/coli stop >/dev/null 2>&1 || true
  rm -rf "$MODEL_DIR"
  echo "=== [$MODEL] deleted weights, free now: $(df -h "$HOME" | tail -1 | awk '{print $4}') ===" | tee -a "$HOME/benchmark-results/serial.log"
done
echo "ALL DONE $(date -Is)" | tee -a "$HOME/benchmark-results/serial.log"
