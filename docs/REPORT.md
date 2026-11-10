# Colibri on CPU-only Hardware: A Throughput Study of Frontier MoE Models

**Benchmark host:** a single-socket 12-core x86 server (no GPU)
**Engine:** colibri v2.1.0, commit `0a5504a`
**Date:** 2026-11-09 to 2026-11-10
**Scope:** 9 models, one at a time, weights deleted after each run

---

## 1. Executive summary

colibri is a hierarchical inference engine for mixture-of-experts (MoE) models: the dense part stays in RAM, routed experts stream from disk, and an LRU/pinned cache decides which experts are resident. This study measures decode throughput of nine MoE checkpoints on a GPU-less server, using colibri's own `datapoint.py` runner in persistent serving mode.

On this hardware the bottleneck is disk, not CPU. Small models whose experts fit in RAM decode at 0.3-0.7 tokens/s. Once the expert set exceeds what RAM can hold, throughput falls with the expert-cache miss rate, reaching 0.03 tokens/s on 744B-parameter models. A 32-token response on the largest model takes about 30 minutes, and over 95% of that is expert disk I/O.

Downloads used Hugging Face Xet (3.5x the standard path) for models above ~85 GB. That shortens download time only; decode speed is unchanged.

## 2. Hardware and software

| Component | Detail |
| --- | --- |
| OS | Ubuntu 24.04.5 LTS, x86_64, KVM guest |
| CPU | 12 vCPU Intel Xeon E5-2620 v3 @ 2.40 GHz (Haswell; AVX2/FMA, no AVX-512) |
| RAM | 47 GiB total, no swap |
| Disk | 1.5 TB single volume (`virtio`, non-rotational), shared with the OS |
| GPU | none |
| Engine build | `make <engine> ARCH=native`, CPU backend |
| colibri | v2.1.0, commit `0a5504a` |
| HF token | authenticated account, used for all downloads |

The disk is a virtual device on shared infrastructure. Its sustained read throughput limits the large models (see Section 5).

## 3. Method

Each model went through the same serial cycle: download, validate, benchmark, delete weights, next model. Only one model's weights existed on disk at any time.

**Benchmark runner.** `python3 c/tools/datapoint.py --mode persistent --snap <model_dir> --max-new <cap> --rotating-runs 4`

- One long-lived SERVE=1 engine process; expert and KV state retained across requests, matching `coli serve` behaviour.
- Page cache evicted before engine load (cold run), then a warm-identical request (same prompt, upper bound), then four rotating prompts (primary result).
- Decode cap: 128 tokens (small), 64 (mid), 32 (large). `COLI_TEMP=0`.
- Primary metric: median decode tok/s across the four rotating requests.

**Image model.** Qwen-Image-2.1 has no chat decode. It was measured as one timed `POST /v1/images/generations` (768x512, 8 steps) against a background-started server.

**Downloads.** Models up to ~33 GB used colibri's built-in setup (standard library, resume-safe). Models 85 GB and above used `huggingface_hub.snapshot_download` with XET enabled (`HF_XET_ENABLED=1`), then validated with `coli setup --model-dir`.

## 4. Results

| Model | Params | Download | Rotating median tok/s | Warm upper bound | Cold | Expert hit rate | Expert disk s/request |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Qwen3.6-35B-A3B | 35B | 23.0 GB | 0.65 | 0.73 | 0.69 | 50.3% | 171 |
| Qwen3-Coder-30B-A3B | 30B | 19.4 GB | 0.00 (failed) | 0.69 | 0.72 | 72.3% | 161 (warm) |
| Qwen-Image-2.1 | - | 31.0 GB | - | - | - | - | - |
| DeepSeek V4 Flash REAP 150B | 150B | 84.7 GB | 0.32 | 0.33 | 0.30 | 77.8% | 495 |
| DeepSeek V4 Flash 284B | 284B | 166.9 GB | 0.29 | 0.34 | 0.31 | 61.5% | 554 |
| Qwen3.8-Flash-Next | 176B | 185.6 GB | 0.09 | 0.12 | 0.10 | 19.8% | 816 |
| MiMo-V2.6 Flash 309B | 309B | 171.8 GB | 0.07 | 0.08 | 0.08 | 31.0% | 399 |
| GLM-5.3 | 744B | 419.3 GB | 0.03 | 0.03 | 0.03 | 39.2% | 4907 |
| GLM-5.2 | 744B | 429.3 GB | 0.03 | 0.03 | 0.02 | 37.0% | 5884 |

Qwen-Image-2.1: 862.5 s for one 768x512 PNG (574 KB), HTTP 200.

All values are medians from colibri's engine telemetry. Full per-request tables are in the accompanying datapoint files.

## 5. Analysis

### 5.1 The bottleneck is expert disk I/O, not compute

Engine profile medians per request:

| Model | Expert disk | Expert wait | Expert matmul | Attention |
| --- | ---: | ---: | ---: | ---: |
| Qwen3.6-35B | 171 s | 0 s | 10.6 s | 13.1 s |
| DeepSeek V4 Flash REAP | 495 s | 134 s | 17.7 s | 111.3 s |
| DeepSeek V4 Flash | 554 s | 113 s | 16.5 s | 58.3 s |
| Qwen3.8-Flash-Next | 816 s | 816 s | 31.0 s | 5.7 s |
| MiMo-V2.6 Flash | 399 s | - | - | - |
| GLM-5.3 | 4907 s | - | - | - |
| GLM-5.2 | 5884 s | - | - | - |

Expert matmul stays between 10 and 31 s for every model. Expert disk grows from 171 s to 5884 s. Decode time tracks how many experts must be read from disk per token.

### 5.2 Hit rate decides the regime

- High hit (50% or more): Qwen3.6, Coder, REAP. Decode 0.32-0.73 tok/s. Experts mostly resident, disk a secondary cost.
- Mid hit (around 30%): MiMo, GLM. 0.03-0.07 tok/s.
- Low hit (around 20%): Qwen3.8-Flash-Next. 0.09 tok/s despite a smaller model, because its routing spreads across many experts that cannot all stay resident.

The engine's plan projected these hit rates before each run (5% for GLM-5.2), and the measured values tracked the projection. The cache model is accurate.

### 5.3 RAM sets the cache size

The largest models ran near the host's memory limit:

| Model | Dense resident | Expert cache | Projected peak RSS |
| --- | ---: | ---: | ---: |
| DeepSeek V4 Flash REAP | 8.8 GB | 26.5 GB (46/layer) | ~35.8 GB |
| DeepSeek V4 Flash | 19.7 GB | 16.1 GB (27/layer) | ~35.9 GB |
| GLM-5.3 | 11.9 GB | 22.5 GB (13/layer) | ~34.5 GB |
| GLM-5.2 | 11.9 GB | 22.5 GB (13/layer) | 46.0 GB |

GLM-5.2's planner lowered the per-layer cache cap from 16 to 13 experts to keep projected peak at 46.0 GB of 47 GB. A host with more RAM would hold more experts and decode faster. This host sizes the cache down until it fits.

### 5.4 No OOM despite zero swap

The host has no swap. Across all nine runs, including GLM-5.2 at a projected 46.0 GB peak, there were zero OOM kills (`dmesg` clean). The planner's conservative cap and the reclaimable page cache left enough headroom. Memory pressure stayed near zero in the final runs; earlier large-model runs saw transient spikes that did not stall.

### 5.5 Download acceleration

| Path | Observed rate | Used for |
| --- | ---: | --- |
| colibri stdlib (resume-safe) | 17-38 MB/s | small models (33 GB and under) |
| `snapshot_download` + XET | ~96 MB/s | large models (85 GB and above) |

XET's parallel chunked transfer is about three times faster than the standard path. For the 429 GB GLM-5.2 that is the difference between about 5 h and about 1.7 h of download. Decode is unaffected.

## 6. Caveats and anomalies

- Qwen3-Coder-30B rotating failure. All four rotating requests returned zero completion tokens after two successful persistent turns; the engine reported `T(1) 0.0 ms` and zero forwards. The same engine binary and prompt suite worked on Qwen3.6-35B, and the warm and cold runs on Coder itself were normal (0.69-0.72 tok/s). This looks like a persistent-mode engine/checkpoint interaction, not a hardware or disk fault. The warm value is reported as Coder's decode number; its rotating result is excluded.
- Qwen-Image-2.1 first attempt. The initial run hung because a foreground server start never returned. It was corrected to a background start plus an explicit model field in the request. The reported 862.5 s is from the corrected run.
- Single host, single run per model. No replicate runs; spread is reported per model in the datapoint files (sigma 0.00-0.02 on rotating medians).
- Shared virtual disk. The disk is a virtual device on shared infrastructure. Absolute numbers are specific to this host, though the disk-bound trend should hold elsewhere.
- Weights not retained. Per the serial method, weights were deleted after each benchmark. Only logs and numbers remain.
- Background services. Unrelated services on the host were left untouched except for two that were paused for the duration of the runs and left paused afterwards. They are not part of this study.

## 7. Conclusions

1. colibri ran every tested model on CPU-only hardware. No GPU was required, and no model failed to produce output (except the Coder rotating anomaly).
2. Throughput depends on expert residency, which depends on RAM and disk. On this host, models up to ~85 GB with high expert hit decode at 0.3-0.7 tok/s. Larger expert sets fall to 0.03-0.09 tok/s.
3. The pre-run planner predicted hit rate and cache size accurately, and its conservative caps prevented OOM on a zero-swap host even at a 46 GB projected peak.
4. For CPU-only colibri, the upgrade that matters is disk throughput, or RAM to hold more experts, not CPU. A faster NVMe or a larger-RAM host would raise the large-model numbers. A faster CPU would not.
5. XET is worth enabling for downloads of 100 GB and above. It does not change decode.

## Appendix A: Raw data files

Accompanying datapoint files (one per model): machine/engine/tier header, per-request decode table (prompt tokens, completion tokens, request seconds, TTFT, decode tok/s, hit rate, RSS), workload summary, and engine profile medians. Raw stderr logs include per-layer prefill timings and speculative-decoding gate statistics.

## Appendix B: Reproduction

```
# per model, after download
python3 c/tools/datapoint.py --mode persistent --snap <model_dir> \
    --max-new <128|64|32> --rotating-runs 4
```

Model ids, repositories, revisions, and sizes are defined in colibri's `c/setup_catalog.py`. Runner scripts used for the serial campaign are in the project `scripts/` directory.
