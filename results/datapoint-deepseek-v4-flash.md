**Datapoint (automated runner)**

| component | detail |
|---|---|
| machine | Intel(R) Xeon(R) CPU E5-2620 v3 @ 2.40GHz |
| RAM | 47 GB |
| CPU topology | 12 physical / 12 logical |
| OS | Linux-6.8.0-147-generic-x86_64-with-glibc2.39 |
| mode | persistent: one SERVE=1 process; expert/KV/GPU state retained across requests |
| engine | deepseek_v4 (DeepSeek V4 Flash) |
| snapshot | /home/tejes/colibri-models/deepseek-v4-flash |
| cache settings | cap=16, RAM=47.04145812988281 GB |
| OpenMP team | engine runtime auto |
| V4 loader lanes | engine default |
| engine load | 39.15 s |
| GPU | v4-cpu (0 device(s), 0.00 GB VRAM) |
| expert tiers | VRAM 0 / RAM 2279 / disk 8729 (0.00 + 30.47 GB resident) |
| prompt workload | 4 built-in prompts, fixed rotation |

**Decode (COLI_TEMP=0, capped at 32 tokens; actual counts from engine):**

| phase | prompt tok | completion tok | request s | TTFT s | decode tok/s | hit | RSS |
|---|---:|---:|---:|---:|---:|---:|---:|
| cold request (cache evicted before engine load) | 23 | 32 | 191.12 | 88.48 | 0.31 | 62.6% | 35.88 GB |
| warm-identical 1 (upper bound) | 23 | 32 | 144.47 | 51.05 | 0.34 | 72.1% | 35.89 GB |
| rotating 1 (primary) | 27 | 32 | 191.53 | 75.89 | 0.28 | 60.8% | 35.91 GB |
| rotating 2 (primary) | 29 | 32 | 185.11 | 74.27 | 0.29 | 62.1% | 35.95 GB |
| rotating 3 (primary) | 32 | 32 | 195.27 | 84.26 | 0.29 | 58.5% | 35.95 GB |
| rotating 4 (primary) | 36 | 32 | 180.20 | 82.07 | 0.33 | 64.9% | 35.96 GB |

**Workload summary:**

| workload | n | median tok/s | sigma tok/s | p95 request s | median hit |
|---|---:|---:|---:|---:|---:|
| **rotating prompts (primary)** | 4 | 0.29 | 0.019 | 194.71 | 61.5% |
| warm-identical (upper bound) | 1 | 0.34 | 0.000 | 144.47 | 72.1% |

**Rotating workload profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 554.062 |
| expert wait | 112.756 |
| expert matmul | 16.451 |
| attention | 58.280 |
| lm head | 2.489 |

**Warm-identical upper bound profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 302.201 |
| expert wait | 65.715 |
| expert matmul | 16.567 |
| attention | 59.700 |
| lm head | 2.459 |

Rotating prompts are the primary serving result: each request changes prompt
while the engine and expert cache remain alive. Warm-identical intentionally reuses
the same prompt and cache slot and is reported only as a cache/KV upper bound.
