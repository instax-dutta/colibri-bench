**Datapoint (automated runner)**

| component | detail |
|---|---|
| machine | x86_64 |
| RAM | 47 GB |
| CPU topology | 12 physical / 12 logical |
| OS | Linux-6.8.0-147-generic-x86_64-with-glibc2.39 |
| mode | persistent: one SERVE=1 process; expert/KV/GPU state retained across requests |
| engine | mimo (MiMo-V2.6 Flash) |
| snapshot | /home/tejes/colibri-models/mimo-v2.6-flash |
| cache settings | cap=16, RAM=47.04145812988281 GB |
| OpenMP team | 12 |
| V4 loader lanes | n/a |
| engine load | 25.94 s |
| prompt workload | 4 built-in prompts, fixed rotation |

**Decode (COLI_TEMP=0, capped at 32 tokens; actual counts from engine):**

| phase | prompt tok | completion tok | request s | TTFT s | decode tok/s | hit | RSS |
|---|---:|---:|---:|---:|---:|---:|---:|
| cold request (cache evicted before engine load) | 29 | 32 | 411.77 | 156.83 | 0.08 | 34.4% | 20.29 GB |
| warm-identical 1 (upper bound) | 29 | 32 | 409.04 | 158.60 | 0.08 | 34.6% | 20.29 GB |
| rotating 1 (primary) | 32 | 32 | 445.00 | 172.26 | 0.07 | 30.4% | 20.29 GB |
| rotating 2 (primary) | 33 | 32 | 440.44 | 171.03 | 0.07 | 31.6% | 20.29 GB |
| rotating 3 (primary) | 37 | 32 | 469.85 | 187.00 | 0.07 | 28.3% | 20.29 GB |
| rotating 4 (primary) | 43 | 32 | 436.62 | 191.39 | 0.07 | 35.3% | 20.30 GB |

**Workload summary:**

| workload | n | median tok/s | sigma tok/s | p95 request s | median hit |
|---|---:|---:|---:|---:|---:|
| **rotating prompts (primary)** | 4 | 0.07 | 0.002 | 466.12 | 31.0% |
| warm-identical (upper bound) | 1 | 0.08 | 0.000 | 409.04 | 34.6% |

**Rotating workload profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 398.557 |
| expert wait | 0.000 |
| expert matmul | 23.170 |
| attention | 18.094 |
| lm head | 0.000 |

**Warm-identical upper bound profile medians (engine telemetry):**

| phase | seconds/request |
|---|---|
| expert disk | 366.593 |
| expert wait | 0.000 |
| expert matmul | 21.459 |
| attention | 17.512 |
| lm head | 0.000 |

Rotating prompts are the primary serving result: each request changes prompt
while the engine and expert cache remain alive. Warm-identical intentionally reuses
the same prompt and cache slot and is reported only as a cache/KV upper bound.
