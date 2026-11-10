**Datapoint (automated runner)**

| component | detail |
|---|---|
| machine | Intel(R) Xeon(R) CPU E5-2620 v3 @ 2.40GHz |
| RAM | 47 GB |
| CPU topology | 12 physical / 12 logical |
| OS | Linux-6.8.0-147-generic-x86_64-with-glibc2.39 |
| mode | persistent: one SERVE=1 process; expert/KV/GPU state retained across requests |
| engine | colibri (GLM-5.2/5.3) |
| snapshot | /home/tejes/colibri-models/glm-5.3 |
| cache settings | cap=16, RAM=47.04145812988281 GB |
| OpenMP team | 12 |
| V4 loader lanes | n/a |
| engine load | 68.94 s |
| expert tiers | VRAM 0 / RAM 1125 / disk 18075 (0.00 + 23.89 GB resident) |
| prompt workload | 4 built-in prompts, fixed rotation |

**Decode (COLI_TEMP=0, capped at 32 tokens; actual counts from engine):**

| phase | prompt tok | completion tok | request s | TTFT s | decode tok/s | hit | RSS |
|---|---:|---:|---:|---:|---:|---:|---:|
| cold request (cache evicted before engine load) | 26 | 32 | 1729.98 | 611.73 | 0.03 | 37.6% | 34.22 GB |
| warm-identical 1 (upper bound) | 26 | 32 | 1120.73 | 47.08 | 0.03 | 37.9% | 34.22 GB |
| rotating 1 (primary) | 29 | 32 | 1537.43 | 484.78 | 0.03 | 40.2% | 34.53 GB |
| rotating 2 (primary) | 30 | 32 | 1573.72 | 489.94 | 0.03 | 38.3% | 34.53 GB |
| rotating 3 (primary) | 34 | 32 | 1697.12 | 548.68 | 0.03 | 34.0% | 34.53 GB |
| rotating 4 (primary) | 37 | 32 | 1495.06 | 518.19 | 0.03 | 44.5% | 34.53 GB |

**Workload summary:**

| workload | n | median tok/s | sigma tok/s | p95 request s | median hit |
|---|---:|---:|---:|---:|---:|
| **rotating prompts (primary)** | 4 | 0.03 | 0.000 | 1678.61 | 39.2% |
| warm-identical (upper bound) | 1 | 0.03 | 0.000 | 1120.73 | 37.9% |

**Rotating workload profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 4907.278 |
| expert wait | 984.322 |
| expert matmul | 37.477 |
| attention | 37.329 |
| lm head | 0.000 |

**Warm-identical upper bound profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 5224.739 |
| expert wait | 990.664 |
| expert matmul | 37.153 |
| attention | 37.004 |
| lm head | 0.000 |

Rotating prompts are the primary serving result: each request changes prompt
while the engine and expert cache remain alive. Warm-identical intentionally reuses
the same prompt and cache slot and is reported only as a cache/KV upper bound.
