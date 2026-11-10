# Colibri CPU-only benchmark plan

Goal: measure colibri throughput on a GPU-less server, one model at a time,
downloading weights, benchmarking, then deleting weights before the next model.

## Server

- Host: Ubuntu 24.04.5 LTS, x86_64, KVM VM, no GPU (no nvidia, no /dev/dri)
- CPU: 12 vCPU Intel Xeon E5-2620 v3 @ 2.40GHz (Haswell, AVX2/FMA, no AVX-512)
- RAM: 47 GiB total, ~42 GiB available at check time, 0 swap - no swap buffer
- Disk: 1.5 TB single disk (virtio, non-rotational), 1.3 TB free at check time
- Disk is also the root partition - keep 50-100 GB headroom, never fill root
- Toolchain present locally on server: python3.12, gcc 13.3, hdparm, iostat
- Colibri not yet installed at plan time: no checkout, no model dir, no coli binary
- Unrelated services on the host were left untouched except two that were
  paused for the run and left paused afterwards (not part of this study)

## Colibri: what it supports

Source: https://github.com/JustVugg/colibri - 12 one-step models in c/setup_catalog.py,
plus manual-convert models, GGUF-import models, and decision models.
Colibri runs every engine on CPU with no GPU required.
Download = Hugging Face repo size in GB (10^9 bytes). Disk need = download*1.02 + 2 GB.
RAM min = dense part + smallest expert cache (below it does not start).
RAM good = where docs measured it.

## Benchmarkable (fits disk + RAM)

### One-step catalog (download and run directly)

| Model | --model ID | Download | RAM min / good | Notes |
| --- | --- | --- | --- | --- |
| Qwen3.6-35B-A3B | qwen36-35b | 23.1 GB | 10 / 20 GB | small, from RAM |
| Qwen3-Coder-30B-A3B | qwen3-coder-30b | 19.4 GB | 8 / 18 GB | small, from RAM |
| Qwen-Image-2.1 (image gen) | qwen-image-2.1 | 33.1 GB | 12 / 18 GB | small, from RAM |
| DeepSeek V4 Flash REAP 150B | deepseek-v4-flash-reap | 84.7 GB | 16 / 32 GB | large, experts stream from disk |
| DeepSeek V4 Flash 284B | deepseek-v4-flash | 166.9 GB | 16 / 32 GB | large, streams |
| Qwen3.8-Flash-Next | qwen38-flash-next | 185.6 GB | 24 / 32 GB | large, streams |
| MiMo-V2.6 Flash 309B | mimo-v2.6-flash | 171.8 GB | 32 / 52 GB | large, streams - tight on RAM (has ~50 GB) |
| GLM-5.2 744B | glm-5.2 | 429.3 GB | 16 / 24 GB | large, streams |
| GLM-5.3 744B | glm-5.3 | 419.3 GB | 16 / 24 GB | large, streams |

### Manual / GGUF (fits with conversion or import step)

- OLMoE 7B: 14 GB download, convert to int8 (~7 GB), 8 GB RAM
- Qwen3.8-27B dense: 56 GB, convert to int4 (20 GB) / int8 (30 GB)
- GLM-5.3-Flash 321B: 328 GB, shard-convert to 195 GB, 25 GB RAM
- DeepSeek V4.1 Flash 552B: 510 GB, ~18 GB RAM + expert cache
- GGUF: Mistral-Large-4 UD-IQ1_S 233 GB, Muse Spark Open 176-505 GB by quant, Flint 11.4-79.6 GB, LFM3-VL-2B small
- Decision: Laya 0.85 GB / 1.7 GB RAM, GLiNER2.5-Decide 1.95 GB / 1.9 GB RAM, Clef 55 GB / 19-55 GB RAM

### NOT benchmarkable as downloaded

- Kimi K3 (2.8T): 1.56 TB download - exceeds 1.3 TB free
- MiMo-V2.6 Pro (1.02T): 563.6 GB, needs 54 GB RAM min - exceeds ~50 GB total
- Inkling (975B): 514.1 GB, needs 120 GB RAM as downloaded (25 GB after dense conversion per docs - possible with that extra step)

## Benchmark method (serial, delete between models)

1. Ensure nothing heavy running (check ps/load). Ask before pausing or stopping anything. One contender at a time.
2. Record baseline: free -h, df -h, uptime, top CPU/mem processes.
3. Install colibri once (clone + build CPU backend), record commit hash and coli version.
4. For each model, in order:
   a. df -h check free space > need (download*1.02 + 2 GB + 50 GB headroom).
   b. Download weights only (no other model present).
   c. Benchmark throughput with colibri CPU backend (decode tok/s, rotating prompts, note cache state).
   d. Save raw log + summary row to results/.
   e. Delete weights (rm -rf the model dir), confirm df free recovered.
   f. Next model.
5. Small models first (qwen36-35b, qwen3-coder-30b, qwen-image-2.1) to validate CPU build, then one large streaming model at a time.

## Safety rules

- Never touch other services on the host without approval per case.
- Never fill root disk - single disk holds OS and models.
- Zero swap: tight-RAM runs (mimo-v2.6-flash) can OOM - watch dmesg/OOM logs during benchmark.
- One heavy benchmark job at a time.

## Execution status

- Serial runner (small): scripts/bench-serial.sh; large: scripts/bench-xet-large.sh (XET via snapshot_download) + scripts/xet-handover.sh (waits for qwen-image done, stops old loop, starts XET loop). Logs in benchmark-results/ on the server (serial.log, setup-<id>.log, datapoint-<id>.md, summary.tsv, serial-xet.log)
- Colibri checkout: commit 0a5504a, engines built CPU ARCH=native
- Launched 2026-11-09, finished 2026-11-10. Order: qwen36-35b, qwen3-coder-30b, qwen-image-2.1, deepseek-v4-flash-reap, deepseek-v4-flash, qwen38-flash-next, mimo-v2.6-flash, glm-5.3, glm-5.2
- Benchmark method: c/tools/datapoint.py --mode persistent --snap <dir> (rotating prompts = primary), max-new 128 small / 64 mid / 32 large. qwen-image-2.1 uses timed /v1/images/generations instead.
- Monitoring: periodic polls of coli status --json (phase %, rate, eta), serial.log transitions, summary.tsv rows, df/free, process liveness. Reruns are resume-safe; failure should not waste time.
- Pitfalls log (final report):
  - qwen3-coder-30b rotating 0.00 tok/s: Colibri qwen36 persistent-mode stall after 2 turns (warm 0.69 valid, rotating 4/4 zero tokens). Server/disk ruled out (same engine/prompts worked for qwen36-35b).
  - qwen-image-2.1 hang: bench-serial.sh ran `coli start` in foreground (never returns), so server idled 41 min (RSS 13.3 GB, 3 min CPU) without ever reaching curl. Fix: `coli start --background --no-browser`, wait for `ready`, then `POST /v1/images/generations` with `"model":"qwen-image-2.1-colibri"` (missing model field gives 404 `model: None`). Generation supervised via detached curl + `--max-time 900`, single instance only (duplicate curls removed).
  - Summary TSV headline extraction: original grep matched paragraph; fixed to bold table row `**rotating prompts` (running loop left untouched intentionally; rows corrected manually).

## Results location

- results/results.tsv: one row per model (model id, download GB, decode tok/s, notes)
- results/datapoint-<model>.md + .stderr.log: full log per model
- results/README-BENCHMARK.md: brief info file for the zip
- docs/REPORT.md: final in-depth research report (numbers match results.tsv exactly)
