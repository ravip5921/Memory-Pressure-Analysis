# Memory-Pressure-Analysis

## Plan: Docker Completion and WSL-KVM Ramp

Complete Docker experiments with reproducible, internally consistent settings first, using one global no-stress baseline and fixed AB concurrency across all runs; then setup KVM experiments in linux

**Steps**
1. Phase 1: Normalize experiment semantics for Docker (blocks all later execution)
2. Decide and codify one baseline definition: single global baseline only, no stress container, fixed swappiness value documented in outputs/notes.
3. Align ApacheBench concurrency policy to fixed value for both stressed and baseline runs; remove stress-level-dependent branching so comparison is apples-to-apples.
4. Ensure matrix runner executes only stressed permutations, while baseline is executed explicitly once before matrix runs; keep ordering deterministic.
5. Phase 2: Harden collection and analysis pipeline (depends on 1-4)
6. Update summarization logic to explicitly encode baseline metadata in output table (baseline mode, baseline swappiness, AB concurrency, run timestamp) while keeping slowdown formula tied to global baseline.
7. Add run-manifest style metadata capture per run (effective config resolved from configs, image tag, kernel/swappiness used) to support reproducibility in report appendix.
8. Add pre-flight checks in scripts (required Docker image, required tools, writable results path, permission to apply sysctl) and clear fail messages.
9. Phase 3: Execute Docker campaign and analyze (depends on 5-8)
10. Run baseline once, then full stressed matrix (3 swappiness x 3 stress levels), with planned repetitions per configuration for variance estimation.
11. Aggregate and compute mean and spread (at minimum mean + stddev or median + IQR) for Req/sec, p95/p99 (if available from AB output), failed requests, vmstat deltas, slowdown.
12. Generate report-ready artifacts: summary CSV, per-config comparison table, and plots for throughput/slowdown vs swappiness and stress.
13. Phase 4: KVM feasibility gate (parallel with documentation polish after Docker run starts)
14. Validate hardware/host prerequisites for kvm experiment setup in linux

**Relevant files**
- f:/MS-CS-UNO/SP26/OS/Project/Memory-Pressure-Analysis/experiments/run_one.sh - align fixed AB concurrency and keep stressed-run orchestration stable.
- f:/MS-CS-UNO/SP26/OS/Project/Memory-Pressure-Analysis/experiments/run_base.sh - enforce single global baseline behavior and emit baseline metadata.
- f:/MS-CS-UNO/SP26/OS/Project/Memory-Pressure-Analysis/experiments/run_matrix.sh - preserve stressed matrix execution order and optional repetition loop.
- f:/MS-CS-UNO/SP26/OS/Project/Memory-Pressure-Analysis/experiments/configs.sh - centralize fixed AB concurrency, baseline swappiness constant, repetition count.
- f:/MS-CS-UNO/SP26/OS/Project/Memory-Pressure-Analysis/experiments/summarize.py - keep global baseline slowdown logic while adding metadata columns and repeat-aware aggregation.
- f:/MS-CS-UNO/SP26/OS/Project/Memory-Pressure-Analysis/experiments/compute_slowdown.sh - either deprecate clearly or align with chosen global-baseline policy.
- f:/MS-CS-UNO/SP26/OS/Project/Memory-Pressure-Analysis/notes/observations.md - update methodology notes to reflect final baseline and execution policy.

**Verification**
1. Static verification: shellcheck on experiment scripts and a dry-run mode to validate parameter expansion and output directory naming.
2. Functional verification: baseline run succeeds and writes complete artifact set (ab, vmstat before/after, meminfo before/after, oom logs).
3. Functional verification: matrix run creates exactly 9 stressed result directories per repetition, each with complete artifact set.
4. Analysis verification: summarize step succeeds with no missing-file errors and emits slowdown values consistent with baseline RPS.
5. Consistency verification: same AB concurrency is visible in all baseline and stressed ab command invocations.
6. Reproducibility verification: rerun one selected config and confirm metric variance is within expected bounds and metadata matches script settings.
7. KVM prerequisities met

**Decisions**
- Baseline mode: single global baseline.
- Concurrency mode: fixed concurrency for all runs.
- KVM next step
- Included scope: Docker experiment completion + Docker result analysis + KVM setup planning gate.

**Further Considerations**
1. Baseline swappiness choice should be explicit (recommend 60 as neutral Linux default reference) and recorded in output metadata.
2. Repetition count should be set before execution (recommend 3 repeats/config for practical variance estimation).
3. Tail latency extraction may require parsing additional AB percentile lines to match report claims on p95/p99 directly.