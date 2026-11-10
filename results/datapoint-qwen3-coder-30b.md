**Datapoint (automated runner)**

| component | detail |
|---|---|
| machine | x86_64 |
| RAM | 47 GB |
| CPU topology | 12 physical / 12 logical |
| OS | Linux-6.8.0-147-generic-x86_64-with-glibc2.39 |
| mode | persistent: one SERVE=1 process; expert/KV/GPU state retained across requests |
| engine | qwen36 (Qwen3.6-35B-A3B) |
| snapshot | /home/tejes/colibri-models/qwen3-coder-30b |
| cache settings | cap=16, RAM=47.04145812988281 GB |
| OpenMP team | 12 |
| V4 loader lanes | n/a |
| engine load | 11.09 s |
| prompt workload | 4 built-in prompts, fixed rotation |

**Decode (COLI_TEMP=0, capped at 128 tokens; actual counts from engine):**

| phase | prompt tok | completion tok | request s | TTFT s | decode tok/s | hit | RSS |
|---|---:|---:|---:|---:|---:|---:|---:|
| cold request (cache evicted before engine load) | 31 | 128 | 240.64 | 62.16 | 0.72 | 72.3% | 3.15 GB |
| warm-identical 1 (upper bound) | 31 | 128 | 230.53 | 44.81 | 0.69 | 72.3% | 3.15 GB |
| rotating 1 (primary) | 35 | 0 | 66.14 | 66.14 | 0.00 | 0.0% | 3.15 GB |
| rotating 2 (primary) | 36 | 0 | 58.85 | 58.85 | 0.00 | 0.0% | 3.15 GB |
| rotating 3 (primary) | 40 | 0 | 58.97 | 58.97 | 0.00 | 0.0% | 3.15 GB |
| rotating 4 (primary) | 46 | 0 | 60.58 | 60.58 | 0.00 | 0.0% | 3.16 GB |

**Workload summary:**

| workload | n | median tok/s | sigma tok/s | p95 request s | median hit |
|---|---:|---:|---:|---:|---:|
| **rotating prompts (primary)** | 4 | 0.00 | 0.000 | 65.31 | 0.0% |
| warm-identical (upper bound) | 1 | 0.69 | 0.000 | 230.53 | 72.3% |

**Rotating workload profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 0.000 |
| expert wait | 0.000 |
| expert matmul | 0.000 |
| attention | 0.000 |
| lm head | 0.000 |

**Warm-identical upper bound profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 161.285 |
| expert wait | 0.000 |
| expert matmul | 13.405 |
| attention | 8.821 |
| lm head | 0.000 |

Rotating prompts are the primary serving result: each request changes prompt
while the engine and expert cache remain alive. Warm-identical intentionally reuses
the same prompt and cache slot and is reported only as a cache/KV upper bound.
