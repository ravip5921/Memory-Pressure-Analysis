# KVM Experiments

This directory contains a VM-native version of the memory-pressure experiments.

## Files
- `configs.sh`: central config (swappiness matrix, stress levels, AB settings).
- `preflight.sh`: validates required tools before running experiments.
- `run_base.sh`: runs one global baseline (`results/baseline`).
- `run_one.sh`: runs one stressed configuration (`results/swap_<swappiness>_<stress>_r<repeat>`).
- `run_matrix.sh`: runs the full stressed matrix with repeats.
- `run_matrix_base.sh`: convenience wrapper to run baseline + matrix.
- `summarize.py`: computes raw/aggregated CSV outputs with slowdown against global baseline.

## Quick Start (inside KVM guest)
1. Run preflight checks:
   ```bash
   bash kvm_experiments/preflight.sh
   ```
2. Install Python dependency:
   ```bash
   python3 -m pip install --user -r kvm_experiments/requirements.txt
   ```
3. Run baseline once:
   ```bash
   bash kvm_experiments/run_base.sh
   ```
4. Run stressed matrix:
   ```bash
   bash kvm_experiments/run_matrix.sh
   ```
5. Summarize:
   ```bash
   python3 kvm_experiments/summarize.py
   ```

## One-command baseline + matrix
```bash
bash kvm_experiments/run_matrix_base.sh
```

## Notes
- Use a non-root user; scripts call `sudo` only where required for sysctl/dmesg.
- Results are written to `kvm_experiments/results`.
- Baseline policy is single global baseline at swappiness 60 by default.
