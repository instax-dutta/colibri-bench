#!/usr/bin/env bash
# XET serial benchmark for large models only. Runs after small models done.
# Do not run concurrently with bench-serial.sh.
set -u
cd "$HOME/colibri" || exit 1
mkdir -p "$HOME/benchmark-results"
export HF_XET_ENABLED=1

# model_id max_new repo revision
MODELS=(
  "deepseek-v4-flash-reap 64 puwaer/DeepSeek-V4-Flash-0731-reap-150b main"
  "deepseek-v4-flash 32 deepseek-ai/DeepSeek-V4-Flash-0731 main"
  "qwen38-flash-next 64 Qwen/Qwen3.8-Flash-Next-FP8 bcd9f01ddc9cff2316eb84281bebcd5b058bddce"
  "mimo-v2.6-flash 32 XiaomiMiMo/MiMo-V2.6-Flash-MOPD main"
  "glm-5.3 32 Justvugg/GLM-5.3-colibri-int4-g64 main"
  "glm-5.2 32 mastouri/GLM-5.2-colibri-int4-g64-with-int8-mtp main"
)

SUMMARY="$HOME/benchmark-results/summary-xet.tsv"
printf "model_id\tdownload_gb\tprompt_tok_s\tdecode_tok_s\tcoli_version\tnotes\n" > "$SUMMARY"
COLI_VERSION=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)

for entry in "${MODELS[@]}"; do
  MODEL=$(echo "$entry" | cut -d' ' -f1)
  MAXNEW=$(echo "$entry" | cut -d' ' -f2)
  REPO=$(echo "$entry" | cut -d' ' -f3)
  REV=$(echo "$entry" | cut -d' ' -f4)
  echo "=== [$MODEL XET] start $(date -Is) ===" | tee -a "$HOME/benchmark-results/serial-xet.log"
  df -h "$HOME" | tail -1 >> "$HOME/benchmark-results/serial-xet.log"

  MODEL_DIR="$HOME/colibri-models/$MODEL"
  mkdir -p "$MODEL_DIR"

  # Download via huggingface_hub (XET auto via hf-xet). Token from ~/.cache/huggingface/token.
  echo "=== [$MODEL XET] snapshot_download $REPO@$REV -> $MODEL_DIR ===" | tee -a "$HOME/benchmark-results/serial-xet.log"
  python3 - "$REPO" "$REV" "$MODEL_DIR" <<'PYEOF' > "$HOME/benchmark-results/xet-download-$MODEL.log" 2>&1
import sys, os
os.environ.setdefault("HF_XET_ENABLED", "1")
from huggingface_hub import snapshot_download, get_token
repo, rev, target = sys.argv[1], sys.argv[2], sys.argv[3]
token = get_token()
print(f"repo={repo} rev={rev} token={'yes' if token else 'no'} xet_env={os.environ.get('HF_XET_ENABLED')}", flush=True)
# mimo excludes applied by colibri catalog (engine never loads these)
ignore = []
if repo == "XiaomiMiMo/MiMo-V2.6-Flash-MOPD":
    ignore = ["dflash/*", "audio_tokenizer/*", "model_mtp.safetensors"]
    print(f"ignore={ignore}", flush=True)
snapshot_download(repo_id=repo, revision=rev, local_dir=target, token=token, ignore_patterns=ignore if ignore else None)
print("XET download done", flush=True)
PYEOF
  XET_RC=$?
  tail -n 20 "$HOME/benchmark-results/xet-download-$MODEL.log" >> "$HOME/benchmark-results/serial-xet.log" 2>&1
  if [ $XET_RC -ne 0 ]; then
    echo "=== [$MODEL XET] DOWNLOAD FAILED rc=$XET_RC ====" | tee -a "$HOME/benchmark-results/serial-xet.log"
    printf "%s\t-\t-\t-\t%s\txet_download_failed rc=%s\n" "$MODEL" "$COLI_VERSION" "$XET_RC" >> "$SUMMARY"
    rm -rf "$MODEL_DIR"
    continue
  fi

  # Validate + plan with colibri from existing files (no re-download)
  python3 c/coli setup --yes --model-dir "$MODEL_DIR" --no-start --no-gpu > "$HOME/benchmark-results/setup-xet-$MODEL.log" 2>&1
  SETUP_RC=$?
  tail -n 20 "$HOME/benchmark-results/setup-xet-$MODEL.log" >> "$HOME/benchmark-results/serial-xet.log" 2>&1
  if [ $SETUP_RC -ne 0 ]; then
    echo "=== [$MODEL XET] SETUP FAILED rc=$SETUP_RC ====" | tee -a "$HOME/benchmark-results/serial-xet.log"
    printf "%s\t-\t-\t-\t%s\tsetup_failed rc=%s\n" "$MODEL" "$COLI_VERSION" "$SETUP_RC" >> "$SUMMARY"
    python3 c/coli stop >/dev/null 2>&1 || true
    rm -rf "$MODEL_DIR"
    continue
  fi

  DL_GB=$(du -sb "$MODEL_DIR" 2>/dev/null | cut -f1 | awk '{printf "%.1f", $1/1e9}')
  echo "=== [$MODEL XET] downloaded ${DL_GB}GB, benchmarking (max-new=$MAXNEW) ===" | tee -a "$HOME/benchmark-results/serial-xet.log"

  python3 c/tools/datapoint.py --mode persistent --snap "$MODEL_DIR" --max-new "$MAXNEW" --rotating-runs 4 \
    > "$HOME/benchmark-results/datapoint-$MODEL.md" 2> "$HOME/benchmark-results/datapoint-$MODEL.stderr.log"
  echo "=== [$MODEL XET] datapoint exit $? ===" | tee -a "$HOME/benchmark-results/serial-xet.log"
  HEADLINE=$(grep -a "\*\*rotating prompts" "$HOME/benchmark-results/datapoint-$MODEL.md" | head -1 | awk -F'|' '{gsub(/ /,"",$4); print $4}')
  [ -z "$HEADLINE" ] && HEADLINE="-"
  printf "%s\t%s\t-\t%s\t%s\t%s\n" "$MODEL" "$DL_GB" "$HEADLINE" "$COLI_VERSION" "xet max-new=$MAXNEW; see datapoint-$MODEL.md" >> "$SUMMARY"

  python3 c/coli stop >/dev/null 2>&1 || true
  rm -rf "$MODEL_DIR"
  echo "=== [$MODEL XET] deleted weights, free now: $(df -h "$HOME" | tail -1 | awk '{print $4}') ===" | tee -a "$HOME/benchmark-results/serial-xet.log"
done
echo "ALL DONE $(date -Is)" | tee -a "$HOME/benchmark-results/serial-xet.log"
