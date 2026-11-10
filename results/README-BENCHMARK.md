# Colibri CPU-only benchmark datapoints

Benchmark of [JustVugg/colibri](https://github.com/JustVugg/colibri) (commit `0a5504a`, v2.1.0) running open MoE models on a GPU-less server. Every model was downloaded, benchmarked with colibri's own `datapoint.py`, then its weights deleted before the next model (serial, one at a time).

Full write-up: `docs/REPORT.md` in this repository.

## What is here

- `datapoint-<model>.md` - colibri's standard datapoint report per model (machine, engine, tiers, decode table, workload summary, engine profile)
- `datapoint-<model>.stderr.log` - raw engine stderr (prefill layers, spec gate, cache placement)
- `results.tsv` - one summary row per model (download GB, rotating median tok/s, warm, cold, hit rate)
- `summary-xet.tsv` - the same rows as the runner wrote them
- `serial-xet.log` - the runner log (download/plan/delete transitions per model)

## Server

- Host: Ubuntu 24.04.5 LTS, x86_64, KVM VM, no GPU (no nvidia, no /dev/dri)
- CPU: 12 vCPU Intel Xeon E5-2620 v3 @ 2.40GHz (Haswell, AVX2/FMA, no AVX-512)
- RAM: 47 GiB total, 0 swap
- Disk: 1.5 TB single volume (virtio, non-rotational) - also the OS partition
- Engine: colibri built `ARCH=native`, CPU backend only

## Method

- Text models: `python3 c/tools/datapoint.py --mode persistent --snap <model_dir> --max-new <cap> --rotating-runs 4`
  - One long-lived SERVE=1 engine; expert/KV state retained across requests
  - Page cache evicted before load (cold), then warm-identical upper bound, then 4 rotating prompts (primary result)
  - `max-new`: 128 small / 64 mid / 32 large
- Image model (qwen-image-2.1): timed `POST /v1/images/generations` (768x512, 8 steps) after `coli start --background`
- Downloads: small models via colibri `setup` (stdlib, authenticated HF token); large models via `snapshot_download` with XET (`HF_XET_ENABLED=1`, same token) then `coli setup --yes --model-dir` to validate

## Results

| Model | Download | Rotating median tok/s | Warm upper bound | Cold | Hit rate | Expert disk s/req |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Qwen3.6-35B-A3B | 23.0 GB | 0.65 | 0.73 | 0.69 | 50.3% | 171 |
| Qwen3-Coder-30B-A3B | 19.4 GB | 0.00 (failed) | 0.69 | 0.72 | 72.3% | 161 (warm) |
| Qwen-Image-2.1 | 31.0 GB | - | - | - | - | - |
| DeepSeek V4 Flash REAP 150B | 84.7 GB | 0.32 | 0.33 | 0.30 | 77.8% | 495 |
| DeepSeek V4 Flash 284B | 166.9 GB | 0.29 | 0.34 | 0.31 | 61.5% | 554 |
| Qwen3.8-Flash-Next | 185.6 GB | 0.09 | 0.12 | 0.10 | 19.8% | 816 |
| MiMo-V2.6 Flash 309B | 171.8 GB | 0.07 | 0.08 | 0.08 | 31.0% | 399 |
| GLM-5.3 744B | 419.3 GB | 0.03 | 0.03 | 0.03 | 39.2% | 4907 |
| GLM-5.2 744B | 429.3 GB | 0.03 | 0.03 | 0.02 | 37.0% | 5884 |

Image generation: 862.5 s for one 768x512 PNG (574 KB), HTTP 200.

## Notes

- Rotating median tok/s is the primary number (changing prompts, engine alive). Warm-identical is an upper bound with the same prompt/cache slot.
- qwen3-coder-30b rotating failed: 4/4 rotating requests returned 0 completion tokens (engine stall in persistent mode after 2 turns). Warm 0.69 is the valid decode number; server and disk ruled out (same engine and prompts worked for qwen36-35b).
- Disk-bound, not CPU-bound: expert disk read time dominates (171 s/req small, 5884 s/req glm-5.2) against expert matmul 16-31 s. Larger expert sets on this virtio disk collapse throughput.
- XET vs stdlib downloads: large models via XET ~96 MB/s against ~25 MB/s stdlib (3.5x faster downloads; decode unchanged).
- Zero swap: no OOM occurred, but large models ran near the RAM ceiling (glm-5.2 projected peak 46.0 GB of 47 GB, cap auto-lowered 16 to 13 experts/layer).
- Model weights are not included (deleted after each benchmark per the serial method); only logs and numbers.
- Unrelated services on the host were left untouched except two paused for the run; they are not part of this study.

## Reproduce

```
python3 c/tools/datapoint.py --mode persistent --snap <model_dir> --max-new <cap> --rotating-runs 4
```

Model ids and repos are in colibri `c/setup_catalog.py`; the runner scripts are in `scripts/`.
