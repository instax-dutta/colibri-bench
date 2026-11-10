**Datapoint (automated runner)**

| component | detail |
|---|---|
| machine | x86_64 |
| RAM | 47 GB |
| CPU topology | 12 physical / 12 logical |
| OS | Linux-6.8.0-147-generic-x86_64-with-glibc2.39 |
| mode | persistent: one SERVE=1 process; expert/KV/GPU state retained across requests |
| engine | qwen36 (Qwen3.6-35B-A3B) |
| snapshot | /home/tejes/colibri-models/qwen36-35b |
| cache settings | cap=16, RAM=47.04145812988281 GB |
| OpenMP team | 12 |
| V4 loader lanes | n/a |
| engine load | 20.80 s |
| prompt workload | 4 built-in prompts, fixed rotation |

**Decode (COLI_TEMP=0, capped at 128 tokens; actual counts from engine):**

| phase | prompt tok | completion tok | request s | TTFT s | decode tok/s | hit | RSS |
|---|---:|---:|---:|---:|---:|---:|---:|
| cold request (cache evicted before engine load) | 31 | 128 | 247.27 | 61.52 | 0.69 | 57.8% | 3.11 GB |
| warm-identical 1 (upper bound) | 31 | 128 | 212.30 | 38.19 | 0.73 | 57.8% | 3.11 GB |
| rotating 1 (primary) | 35 | 128 | 253.13 | 48.77 | 0.63 | 49.5% | 3.12 GB |
| rotating 2 (primary) | 36 | 128 | 248.66 | 46.16 | 0.63 | 50.1% | 3.12 GB |
| rotating 3 (primary) | 40 | 128 | 244.25 | 50.41 | 0.66 | 50.5% | 3.12 GB |
| rotating 4 (primary) | 38 | 128 | 231.97 | 41.44 | 0.67 | 54.3% | 3.19 GB |

**Workload summary:**

| workload | n | median tok/s | sigma tok/s | p95 request s | median hit |
|---|---:|---:|---:|---:|---:|
| **rotating prompts (primary)** | 4 | 0.65 | 0.019 | 252.46 | 50.3% |
| warm-identical (upper bound) | 1 | 0.73 | 0.000 | 212.30 | 57.8% |

**Rotating workload profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 171.861 |
| expert wait | 0.000 |
| expert matmul | 10.625 |
| attention | 13.148 |
| lm head | 0.000 |

**Warm-identical upper bound profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 147.163 |
| expert wait | 0.000 |
| expert matmul | 10.541 |
| attention | 13.759 |
| lm head | 0.000 |

Rotating prompts are the primary serving result: each request changes prompt
while the engine and expert cache remain alive. Warm-identical intentionally reuses
the same prompt and cache slot and is reported only as a cache/KV upper bound.
