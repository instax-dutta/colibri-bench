# colibri-bench

Throughput numbers for [colibri](https://github.com/JustVugg/colibri), a hierarchical inference engine for large mixture-of-experts models, running on a CPU-only server with no GPU.

Nine MoE checkpoints, from 19 GB to 429 GB, were downloaded, benchmarked with colibri's own `datapoint.py` runner, and deleted before the next model. The host was a 12-core Intel Xeon E5-2620 v3 (Haswell) with 47 GiB of RAM and a single 1.5 TB virtual disk. No swap, no GPU, no AVX-512.

## Headline result

Small models whose experts fit in RAM decode at 0.3 to 0.7 tokens/s. Once the expert set outgrows RAM, throughput falls with the expert-cache miss rate: 0.09 tok/s on a 176B model, 0.03 tok/s on the 744B models. A 32-token response on the largest model took about 30 minutes, and over 95% of that was reading experts from disk.

Expert matmul stayed between 10 and 31 seconds per request across every model. Expert disk time grew from 171 seconds to 5884 seconds. Decode time tracks disk reads, not compute.

| Model | Download | Rotating median tok/s | Warm | Cold | Hit rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| Qwen3.6-35B-A3B | 23.0 GB | 0.65 | 0.73 | 0.69 | 50.3% |
| Qwen3-Coder-30B-A3B | 19.4 GB | 0.00 (failed) | 0.69 | 0.72 | 72.3% |
| Qwen-Image-2.1 | 31.0 GB | - | - | - | - |
| DeepSeek V4 Flash REAP 150B | 84.7 GB | 0.32 | 0.33 | 0.30 | 77.8% |
| DeepSeek V4 Flash 284B | 166.9 GB | 0.29 | 0.34 | 0.31 | 61.5% |
| Qwen3.8-Flash-Next | 185.6 GB | 0.09 | 0.12 | 0.10 | 19.8% |
| MiMo-V2.6 Flash 309B | 171.8 GB | 0.07 | 0.08 | 0.08 | 31.0% |
| GLM-5.3 744B | 419.3 GB | 0.03 | 0.03 | 0.03 | 39.2% |
| GLM-5.2 744B | 429.3 GB | 0.03 | 0.03 | 0.02 | 37.0% |

Qwen-Image-2.1 produced one 768x512 PNG in 862.5 seconds. Rotating median is the primary metric: four changing prompts against one long-lived engine. Warm is the same-prompt upper bound.

Qwen3-Coder's rotating run failed (engine stall, zero tokens), so its warm value is the decode number. See the caveats section in the report.

## What is in this repo

- `docs/REPORT.md` - the full write-up: method, per-model analysis, RAM ceiling, download paths, caveats
- `docs/benchmark-plan.md` - host specs, model catalog, serial run method, pitfalls
- `results/` - colibri's datapoint reports and raw engine stderr for all nine models, plus the summary tables
- `scripts/` - the runner scripts that did download, benchmark, delete, one model at a time

## Takeaways

- colibri ran every model on CPU alone. No model failed to produce output, apart from the Coder rotating anomaly.
- The engine's pre-run planner predicted hit rate and cache size accurately, and its conservative caps avoided OOM on a zero-swap host even at a 46 GB projected peak.
- For CPU-only colibri, disk throughput (or more RAM to hold experts) is the upgrade that matters, not CPU. A faster NVMe or a larger-RAM host would raise the large-model numbers. A faster CPU would not.
- Hugging Face Xet made large downloads about three times faster (~96 MB/s against ~25 MB/s). It does not change decode.

## Reproduce

```
python3 c/tools/datapoint.py --mode persistent --snap <model_dir> \
    --max-new <128|64|32> --rotating-runs 4
```

Model ids, repositories, and sizes live in colibri's `c/setup_catalog.py`. Weights are not included here; the serial method deleted them after each run.

## License

MIT for this repo's own content. colibri itself is Apache-2.0, and model weights belong to their respective publishers under their own licenses.
