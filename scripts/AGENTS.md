# Scripts - benchmark harness

## Purpose

- Owns the serial benchmark script that downloads, benchmarks, and deletes each model.

## Ownership

- This folder owns `bench-serial.sh` (small models), `bench-xet-large.sh` + `xet-handover.sh` (large models via XET after small are done).
- Parent AGENTS.md owns project workflow. docs/ owns the plan. results/ owns outputs.

## Local Contracts

- `bench-serial.sh` runs one model at a time: `coli setup --yes --model <id> --no-start --no-gpu`, then `datapoint.py --mode persistent --snap <dir> --max-new <cap>` (image model uses timed `/v1/images/generations` instead), then `rm -rf` weights. Output goes to `~/benchmark-results/` on the host.
- `bench-xet-large.sh` (6 large models only: deepseek-v4-flash-reap, deepseek-v4-flash, qwen38-flash-next, mimo-v2.6-flash, glm-5.3, glm-5.2) downloads via `snapshot_download` (XET, token from `~/.cache/huggingface/token`, `HF_XET_ENABLED=1`), then `coli setup --yes --model-dir <dir> --no-start --no-gpu` to validate, then datapoint, then `rm -rf`.
- `xet-handover.sh` waits for `qwen-image-2.1` in `summary.tsv` (small models done), stops `bench-serial.sh`, then starts `bench-xet-large.sh`. Never run two benchmarks concurrently.

## Work Guidance

- Poll with `coli status --json` and `tail ~/benchmark-results/serial.log` on the host.

## Verification

## Child DOX Index
