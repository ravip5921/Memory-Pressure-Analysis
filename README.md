# Memory Pressure Analysis

This repository contains the finished artifacts for the project and paper, "Analyzing the Effects of Memory Pressure on Container and Virtual Machine Performance."

The study compares Docker containers and KVM virtual machines under controlled memory pressure, focusing on throughput, tail latency, slowdown, reclaim behavior, and system stability.

## What This Project Includes

- A Docker-based experiment track in [experiments/](experiments/)
- A KVM-based experiment track in [kvm_experiments/](kvm_experiments/)
- Collected run outputs under [experiments/results/](experiments/results/) and [kvm_experiments/results/](kvm_experiments/results/)
- Aggregation and plotting scripts for the finished datasets
- The paper source in [experiments/report.tex](experiments/report.tex)

## Experiment Summary

Both tracks use the same basic design:

- one global baseline run
- a stressed matrix over swappiness values 10, 60, and 100
- three memory pressure levels: moderate, high, and extreme
- fixed ApacheBench concurrency of 30
- three repeats per stressed configuration

The Docker and KVM runs collect application output together with kernel-level snapshots so that performance changes can be tied to memory reclaim, swap activity, and OOM behavior.

## Repository Layout

- [experiments/](experiments/): Docker experiment scripts, summary CSVs, plots, and report source
- [kvm_experiments/](kvm_experiments/): KVM experiment scripts, preflight checks, summary CSVs, and plots
- [workloads/](workloads/): the latency-sensitive service used during experiments
- [notes/](notes/): experiment notes and observations

## Requirements

### Docker Track

- Linux host with Docker installed
- Python 3
- ApacheBench (`ab`)
- `stress-ng`
- Bash

### KVM Track

The KVM workflow is intended to run inside a Linux guest on a host with KVM/libvirt support. See [kvm_experiments/KVM_SETUP_LINUX.md](kvm_experiments/KVM_SETUP_LINUX.md) for a full host-and-guest setup guide.

Inside the guest, you will need:

- Python 3
- `apache2-utils` for `ab`
- `stress-ng`
- `curl`
- `git`

## Docker Workflow

Run the Docker experiments from the repository root on a Linux host.

```bash
cd experiments
bash run_base.sh
bash run_matrix.sh
python3 summarize.py
python3 plot_results.py
```

If you want to run the full sequence in one pass, use:

```bash
bash run_matrix_base.sh
```

The Docker configuration lives in [experiments/configs.sh](experiments/configs.sh). Key defaults include:

- baseline mode: single global baseline
- baseline swappiness: 60
- ApacheBench concurrency: 30
- repeat count: 3

Outputs are written under [experiments/results/](experiments/results/) and plots are written under [experiments/plots/](experiments/plots/).

## KVM Workflow

Run the KVM experiments from the repository root inside the guest VM.

```bash
cd kvm_experiments
bash preflight.sh
python3 -m pip install --user -r requirements.txt
bash run_base.sh
bash run_matrix.sh
python3 summarize.py
python3 plot_results.py
```

You can also run baseline plus the full matrix together:

```bash
bash run_matrix_base.sh
```

The KVM configuration mirrors the Docker track and uses the same baseline and stress matrix. Outputs are written under [kvm_experiments/results/](kvm_experiments/results/) and plots are written under [kvm_experiments/plots/](kvm_experiments/plots/).

## Expected Outputs

After the experiments complete, you should have:

- per-run artifact directories containing `ab.txt`, `meminfo_before.txt`, `meminfo_after.txt`, `vmstat_before.txt`, `vmstat_after.txt`, `oom.txt`, and run metadata
- summary tables such as `summary_runs_raw.csv` and `summary_aggregated.csv`
- slowdown summaries relative to the global baseline
- plots for throughput, slowdown, and tail latency

The KVM track also retains a legacy-compatible aggregate CSV named `corr_rt_30_timeout_600_with_slowdown_global_baseline_linux_kvm.csv`.

## Reproducing the Paper Figures

The paper source lives in [experiments/report.tex](experiments/report.tex). The figures in the report are generated from the plotted results in the experiment folders.

To update the report artifacts after rerunning the experiments, regenerate the summary tables first and then rerun the plotting scripts.

## Notes

- The repository is organized around completed experiments, not an in-progress development plan.
- The Docker and KVM tracks both use a fixed concurrency policy to keep baseline and stressed runs comparable.
- If a run is interrupted by a timeout or transient failure, rerun the corresponding matrix script; completed result directories are skipped by the KVM workflow.
