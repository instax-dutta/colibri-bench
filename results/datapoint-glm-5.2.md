**Datapoint (automated runner)**

| component | detail |
|---|---|
| machine | Intel(R) Xeon(R) CPU E5-2620 v3 @ 2.40GHz |
| RAM | 47 GB |
| CPU topology | 12 physical / 12 logical |
| OS | Linux-6.8.0-147-generic-x86_64-with-glibc2.39 |
| mode | persistent: one SERVE=1 process; expert/KV/GPU state retained across requests |
| engine | colibri (GLM-5.2/5.3) |
| snapshot | /home/tejes/colibri-models/glm-5.2 |
| cache settings | cap=16, RAM=47.04145812988281 GB |
| OpenMP team | 12 |
| V4 loader lanes | n/a |
| engine load | 40.30 s |
| expert tiers | VRAM 0 / RAM 1062 / disk 18394 (0.00 + 22.77 GB resident) |
| prompt workload | 4 built-in prompts, fixed rotation |

**Decode (COLI_TEMP=0, capped at 32 tokens; actual counts from engine):**

| phase | prompt tok | completion tok | request s | TTFT s | decode tok/s | hit | RSS |
|---|---:|---:|---:|---:|---:|---:|---:|
| cold request (cache evicted before engine load) | 26 | 32 | 1910.87 | 622.46 | 0.02 | 37.1% | 35.33 GB |
| warm-identical 1 (upper bound) | 26 | 32 | 1213.04 | 40.09 | 0.03 | 39.5% | 35.33 GB |
| rotating 1 (primary) | 29 | 32 | 1706.56 | 543.85 | 0.03 | 37.7% | 35.89 GB |
| rotating 2 (primary) | 30 | 32 | 1739.96 | 546.00 | 0.03 | 36.4% | 35.89 GB |
| rotating 3 (primary) | 34 | 32 | 1891.42 | 615.30 | 0.03 | 36.3% | 36.07 GB |
| rotating 4 (primary) | 37 | 32 | 1652.27 | 571.22 | 0.03 | 40.9% | 36.15 GB |

**Workload summary:**

| workload | n | median tok/s | sigma tok/s | p95 request s | median hit |
|---|---:|---:|---:|---:|---:|
| **rotating prompts (primary)** | 4 | 0.03 | 0.000 | 1868.70 | 37.0% |
| warm-identical (upper bound) | 1 | 0.03 | 0.000 | 1213.04 | 39.5% |

**Rotating workload profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 5884.079 |
| expert wait | 1086.865 |
| expert matmul | 40.360 |
| attention | 40.752 |
| lm head | 0.000 |

**Warm-identical upper bound profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 5465.348 |
| expert wait | 1080.036 |
| expert matmul | 42.218 |
| attention | 40.322 |
| lm head | 0.000 |

Rotating prompts are the primary serving result: each request changes prompt
while the engine and expert cache remain alive. Warm-identical intentionally reuses
the same prompt and cache slot and is reported only as a cache/KV upper bound.
