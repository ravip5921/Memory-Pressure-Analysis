# Linux KVM Setup and Experiment Runbook

This guide helps you set up KVM on a Linux host and run your memory-pressure experiments inside a guest VM.

## 1. Verify host virtualization support

```bash
lscpu | grep -E 'Virtualization|Vendor ID'
egrep -c '(vmx|svm)' /proc/cpuinfo
```

Expected: non-zero `vmx` (Intel) or `svm` (AMD).

## 2. Install KVM/libvirt packages

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager virtinst cpu-checker
```

### Fedora/RHEL
```bash
sudo dnf install -y @virtualization virt-install virt-manager
sudo systemctl enable --now libvirtd
```

## 3. Enable and validate libvirt

```bash
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER
```

Log out and back in, then verify:

```bash
virsh list --all
```

If your prompt changes from bash to `virsh #`, you entered interactive mode by running `virsh` alone.
Use `quit` to exit interactive mode.

For one-shot commands, use one of:

```bash
sudo virsh -c qemu:///system list --all
virsh -c qemu:///session list --all
```

## 4. Create a Linux VM (example)

You can use `virt-manager` (GUI) or `virt-install` (CLI).

First, download an ISO (Ubuntu example):

```bash
mkdir -p "$HOME/iso" "$HOME/libvirt-images"
wget -O "$HOME/iso/ubuntu-22.04.5-live-server-amd64.iso" \
  https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso
```

Then create the VM (adjust RAM, CPU, disk, and ISO path as needed):

```bash
sudo virt-install \
  --name mempressure-vm \
  --ram 4096 \
  --vcpus 2 \
  --disk path=$HOME/libvirt-images/mempressure-vm.qcow2,size=30 \
  --osinfo detect=on,name=ubuntu22.04 \
  --network network=default \
  --graphics vnc \
  --cdrom $HOME/iso/ubuntu-22.04.5-live-server-amd64.iso
```

## 5. Prepare guest OS for experiments

Inside the VM:

```bash
sudo apt update
sudo apt install -y python3 python3-pip apache2-utils stress-ng curl git
```

Clone your project in the VM and go to repo root:

```bash
git clone <your-repo-url>
cd Memory-Pressure-Analysis
```

Install Python analysis dependency:

```bash
python3 -m pip install --user -r kvm_experiments/requirements.txt
```

## 6. Configure experiment knobs (optional)

Edit `kvm_experiments/configs.sh` for:
- `AB_CONCURRENCY`
- `REPEAT_COUNT`
- `SWAPPINESS_LEVELS`
- `STRESS_LEVELS`

Keep `AB_CONCURRENCY` fixed across baseline and stressed runs for apples-to-apples comparison.

## 7. Run experiments in the VM

From repo root in guest:

```bash
bash kvm_experiments/preflight.sh
bash kvm_experiments/run_base.sh
bash kvm_experiments/run_matrix.sh
python3 kvm_experiments/summarize.py
```

Or run baseline + matrix together:

```bash
bash kvm_experiments/run_matrix_base.sh
```

## 8. Expected outputs

- Per-run artifacts in `kvm_experiments/results/...`
- Raw run table: `kvm_experiments/summary_runs_raw.csv`
- Aggregated table: `kvm_experiments/summary_aggregated.csv`
- Legacy-compatible aggregate filename: `kvm_experiments/corr_rt_30_timeout_600_with_slowdown_global_baseline_linux_kvm.csv`

## 9. Troubleshooting

- `ab: command not found`: install `apache2-utils` (Debian/Ubuntu).
- `stress-ng: command not found`: install `stress-ng`.
- `permission denied` on sysctl/dmesg: ensure your user can use `sudo`.
- service not reachable on `127.0.0.1:8080`: check `kvm_experiments/results/.../server.log`.
- no baseline found during summarize: run `bash kvm_experiments/run_base.sh` first.
- `virt-install` says qemu cannot access files under your home directory:

  ```bash
  getent passwd libvirt-qemu
  sudo setfacl -m u:libvirt-qemu:--x "$HOME"
  sudo setfacl -m u:libvirt-qemu:rx "$HOME/iso" "$HOME/libvirt-images"
  sudo setfacl -m u:libvirt-qemu:r "$HOME/iso/ubuntu-22.04.5-live-server-amd64.iso"
  ```

  Retry VM creation after applying ACLs:

  ```bash
  sudo virt-install \
    --name mempressure-vm \
    --ram 4096 \
    --vcpus 2 \
    --disk path=$HOME/libvirt-images/mempressure-vm.qcow2,size=30 \
    --osinfo detect=on,name=ubuntu22.04 \
    --network network=default \
    --graphics vnc \
    --cdrom $HOME/iso/ubuntu-22.04.5-live-server-amd64.iso
  ```

  If `setfacl` is not available, install it with `sudo apt install -y acl`.

## 10. Suggested run policy

- Baseline once at swappiness 60.
- Full stressed matrix with 3 repeats/config.
- Keep fixed AB concurrency for all runs.
