---
name: perf-profiler
description: Profiles, diagnoses, and optimizes performance bottlenecks in Python, Java, and TypeScript applications and AWS data pipelines. Use this skill whenever something is slow, memory usage is growing, a Lambda is timing out, a Glue job is taking too long, or latency SLAs are being breached. Activate when someone says "why is this slow", "optimize", "profile", "reduce latency", "cold start", "memory leak", "Glue timeout", or when performance monitoring alerts fire. Don't optimize speculatively: but when there's a real slowness complaint, activate this skill immediately rather than guessing at fixes.
---

# Perf Profiler

Performance profiling and optimization for enterprise Python/Java/TypeScript services and AWS pipelines.

## Profiling workflow (execute in order)

### Step 1: Measure baseline

Always establish a baseline before touching anything. Without a baseline, you can't know whether a change actually improved things or just changed the symptoms.

- Record current metrics: response time (p50/p95/p99), throughput, memory, CPU.
- Identify the specific bottleneck: CPU-bound, I/O-bound, memory-bound, or network-bound: the optimization strategy is completely different for each.
- For AWS: check CloudWatch metrics (Duration, IteratorAge, Errors, Throttles).

### Step 2: Profile

**Python profiling tools:**
- CPU: `cProfile` + `snakeviz`, `py-spy` (sampling, production-safe), `scalene` (CPU+memory+GPU).
- Memory: `tracemalloc`, `memory_profiler`, `objgraph` for reference leaks.
- Line-level: `line_profiler` (`@profile` decorator).
- Data pipelines: Spark UI for stage-level profiling; `explain()` for query plans.

```python
# Quick cProfile usage
import cProfile
cProfile.run('main()', sort='cumulative')

# py-spy (attach to running process)
# py-spy top --pid <PID>
# py-spy record -o profile.svg --pid <PID>
```

**Java profiling tools:**
- CPU: `async-profiler`, JFR (Java Flight Recorder), VisualVM.
- Memory: `jmap -histo`, MAT (Memory Analyzer Tool), JFR heap analysis.
- GC: `-Xlog:gc*` flags, GCViewer.

**TypeScript/Node.js profiling tools:**
- CPU: `--prof` flag + `--prof-process`, `clinic doctor`, `0x` flame graphs.
- Memory: `--inspect` + Chrome DevTools heap snapshots, `clinic heapprofile`.
- Event loop: `clinic bubbleprof` for async bottlenecks.

### Step 3: Identify hotspots

- Sort by cumulative time / self time.
- Look for: tight loops, repeated I/O calls, unnecessary serialization, N+1 queries.
- For data pipelines: look for shuffles, skewed partitions, broadcast join opportunities.

### Step 4: Optimize (targeted changes only)

Apply optimizations to identified hotspots only: never optimize speculatively.

## Optimization patterns by category

### CPU-bound

- Python: use vectorized operations (numpy/pandas) over loops; consider `multiprocessing` or `concurrent.futures`.
- Java: avoid autoboxing in hot loops; use primitive streams; consider parallel streams for large datasets.
- TypeScript: avoid synchronous computation on event loop; offload to worker threads.
- All: algorithmic improvements first (O(n²) -> O(n log n)); micro-optimize only after.

### I/O-bound

- Batch API/DB calls instead of sequential (N+1 -> batch query).
- Use connection pooling: `sqlalchemy` pool (Python), HikariCP (Java), `pg`/`knex` pool (TypeScript).
- Use async I/O: `asyncio`/`aiohttp` (Python), CompletableFuture (Java), native async/await (TypeScript).
- For AWS: use batch APIs (`batch_write_item`, `send_message_batch`).

### Memory-bound

- Python: use generators/iterators over lists for large datasets; avoid global caches without LRU bounds.
- Java: tune heap (`-Xmx`/`-Xms`); use weak references for caches; watch for classloader leaks.
- TypeScript: avoid closure-captured large objects; use streams for file processing.
- Data pipelines: repartition to avoid skew; use columnar formats (Parquet) over row formats (CSV/JSON).

### AWS Lambda specific

- **Cold start reduction:** minimize package size; use layers for shared deps; prefer arm64; use SnapStart (Java).
- **Provisioned concurrency:** for latency-sensitive Lambdas with predictable load.
- **Memory = CPU:** Lambda CPU scales linearly with memory; profile at different memory settings.
- **Connection reuse:** initialize SDK clients outside handler; use `keep-alive` for HTTP.

### PySpark / Glue specific

- Avoid UDFs when Spark native functions exist.
- Use `broadcast()` for small lookup tables (< 100MB).
- Repartition before joins on skewed keys.
- Use `coalesce()` (not `repartition()`) when reducing partitions after filtering.
- Enable Glue auto-scaling; set `--conf spark.sql.adaptive.enabled=true`.
- Use pushdown predicates for S3/Glue catalog reads.

## Rules

- Measure before and after every optimization: changes that don't improve metrics get reverted, regardless of how clever they seem.
- Optimize the biggest bottleneck first (Amdahl's Law): fixing a 5% hotspot while ignoring a 60% hotspot wastes effort.
- Never sacrifice correctness for performance: a fast wrong answer is worse than a slow right one.
- Leave non-obvious optimizations readable with explanatory comments: future maintainers need to understand why the code looks unusual.
- For data pipelines: test with representative data volume, not just small samples: Spark performance characteristics change dramatically at scale.

## Edge cases

- **Intermittent slowness:** likely GC pauses, cold starts, or noisy neighbor: profile under realistic load.
- **Memory leak (gradual growth):** use heap snapshots at intervals; diff to find growing objects.
- **Lambda timeout at 15min:** consider Step Functions or ECS for long-running tasks.
- **Glue job OOM:** increase worker type (G.1X -> G.2X); check for partition skew; reduce broadcast size.
- **Network latency:** verify VPC configuration; use VPC endpoints for AWS services; check DNS resolution.
- **Profiler overhead:** use sampling profilers in production; never use instrumenting profilers in prod.

## Output format

```
## Performance Analysis
**Component:** <service/function/job>
**Baseline:** <p50/p95/p99 or duration>
**Bottleneck type:** CPU / I/O / Memory / Network
**Hotspot:** <file:function:line or Spark stage>
**Root cause:** <why it's slow>
**Optimization:** <specific change>
**Expected improvement:** <estimate>
**After measurement:** <actual result>
```
