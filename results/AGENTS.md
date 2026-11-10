# Results - benchmark outputs

## Purpose

- Owns benchmark outputs: one summary row per model plus full per-model logs.

## Ownership

- This folder owns `results.tsv` and `results/<model>.md`. Everything else (plans) lives in docs/.

## Local Contracts

- One row per completed model in results.tsv: model id, download GB, prompt tok/s, decode tok/s, notes.
- One file per model in results/<model>.md with raw log, exact coli version/commit, command lines, and cache state.
- Only add a row after weights are deleted and disk recovery is confirmed - this proves the serial method.

## Work Guidance

- Record CPU backend, thread count, and prompt used. CPU-only, no GPU, one benchmark at a time.

## Verification

## Child DOX Index
