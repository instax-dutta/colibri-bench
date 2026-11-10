**Datapoint (automated runner)**

| component | detail |
|---|---|
| machine | Intel(R) Xeon(R) CPU E5-2620 v3 @ 2.40GHz |
| RAM | 47 GB |
| CPU topology | 12 physical / 12 logical |
| OS | Linux-6.8.0-147-generic-x86_64-with-glibc2.39 |
| mode | persistent: one SERVE=1 process; expert/KV/GPU state retained across requests |
| engine | deepseek_v4 (DeepSeek V4 Flash) |
| snapshot | /home/tejes/colibri-models/deepseek-v4-flash-reap |
| cache settings | cap=16, RAM=47.04145812988281 GB |
| OpenMP team | engine runtime auto |
| V4 loader lanes | engine default |
| engine load | 25.24 s |
| GPU | v4-cpu (0 device(s), 0.00 GB VRAM) |
| expert tiers | VRAM 0 / RAM 2279 / disk 3397 (0.00 + 30.47 GB resident) |
| prompt workload | 4 built-in prompts, fixed rotation |

**Decode (COLI_TEMP=0, capped at 64 tokens; actual counts from engine):**

| phase | prompt tok | completion tok | request s | TTFT s | decode tok/s | hit | RSS |
|---|---:|---:|---:|---:|---:|---:|---:|
| cold request (cache evicted before engine load) | 23 | 64 | 321.36 | 108.73 | 0.30 | 74.0% | 35.83 GB |
| warm-identical 1 (upper bound) | 23 | 64 | 246.61 | 53.13 | 0.33 | 79.5% | 35.85 GB |
| rotating 1 (primary) | 27 | 64 | 271.13 | 64.68 | 0.31 | 77.4% | 35.85 GB |
| rotating 2 (primary) | 29 | 64 | 250.99 | 63.47 | 0.34 | 79.4% | 35.89 GB |
| rotating 3 (primary) | 32 | 64 | 269.64 | 71.59 | 0.32 | 77.6% | 35.90 GB |
| rotating 4 (primary) | 36 | 64 | 275.72 | 76.60 | 0.32 | 77.9% | 35.91 GB |

**Workload summary:**

| workload | n | median tok/s | sigma tok/s | p95 request s | median hit |
|---|---:|---:|---:|---:|---:|
| **rotating prompts (primary)** | 4 | 0.32 | 0.011 | 275.03 | 77.8% |
| warm-identical (upper bound) | 1 | 0.33 | 0.000 | 246.61 | 79.5% |

**Rotating workload profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 495.125 |
| expert wait | 134.250 |
| expert matmul | 17.654 |
| attention | 111.300 |
| lm head | 5.098 |

**Warm-identical upper bound profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 371.117 |
| expert wait | 117.061 |
| expert matmul | 15.892 |
| attention | 108.645 |
| lm head | 4.971 |

Rotating prompts are the primary serving result: each request changes prompt
while the engine and expert cache remain alive. Warm-identical intentionally reuses
the same prompt and cache slot and is reported only as a cache/KV upper bound.
