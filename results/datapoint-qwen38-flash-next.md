**Datapoint (automated runner)**

| component | detail |
|---|---|
| machine | x86_64 |
| RAM | 47 GB |
| CPU topology | 12 physical / 12 logical |
| OS | Linux-6.8.0-147-generic-x86_64-with-glibc2.39 |
| mode | persistent: one SERVE=1 process; expert/KV/GPU state retained across requests |
| engine | qwen38 (Qwen3.8-Flash-Next) |
| snapshot | /home/tejes/colibri-models/qwen38-flash-next |
| cache settings | cap=16, RAM=47.04145812988281 GB |
| OpenMP team | 12 |
| V4 loader lanes | n/a |
| engine load | 37.03 s |
| prompt workload | 4 built-in prompts, fixed rotation |

**Decode (COLI_TEMP=0, capped at 64 tokens; actual counts from engine):**

| phase | prompt tok | completion tok | request s | TTFT s | decode tok/s | hit | RSS |
|---|---:|---:|---:|---:|---:|---:|---:|
| cold request (cache evicted before engine load) | 31 | 64 | 811.01 | 186.69 | 0.10 | 25.9% | 11.74 GB |
| warm-identical 1 (upper bound) | 31 | 64 | 540.57 | 32.77 | 0.12 | 27.8% | 11.74 GB |
| rotating 1 (primary) | 35 | 64 | 867.16 | 174.78 | 0.09 | 19.6% | 11.74 GB |
| rotating 2 (primary) | 36 | 64 | 680.34 | 161.30 | 0.12 | 20.0% | 11.74 GB |
| rotating 3 (primary) | 40 | 64 | 932.12 | 205.58 | 0.09 | 17.9% | 11.74 GB |
| rotating 4 (primary) | 38 | 64 | 930.02 | 172.31 | 0.08 | 23.3% | 11.74 GB |

**Workload summary:**

| workload | n | median tok/s | sigma tok/s | p95 request s | median hit |
|---|---:|---:|---:|---:|---:|
| **rotating prompts (primary)** | 4 | 0.09 | 0.015 | 931.81 | 19.8% |
| warm-identical (upper bound) | 1 | 0.12 | 0.000 | 540.57 | 27.8% |

**Rotating workload profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 816.475 |
| expert wait | 816.475 |
| expert matmul | 31.027 |
| attention | 5.724 |
| lm head | 1.301 |

**Warm-identical upper bound profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 488.678 |
| expert wait | 488.678 |
| expert matmul | 21.233 |
| attention | 4.538 |
| lm head | 1.097 |

Rotating prompts are the primary serving result: each request changes prompt
while the engine and expert cache remain alive. Warm-identical intentionally reuses
the same prompt and cache slot and is reported only as a cache/KV upper bound.
