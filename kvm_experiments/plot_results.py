#!/usr/bin/env python3
import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

try:
    import seaborn as sns

    USE_SNS = True
except Exception:
    USE_SNS = False


STRESS_ORDER = ["moderate", "high", "extreme"]


def ensure_numeric(df, cols):
    for col in cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


def load_inputs(raw_path, agg_path, legacy_path):
    raw = pd.read_csv(raw_path)
    agg = pd.read_csv(agg_path)
    legacy = pd.read_csv(legacy_path)

    raw = ensure_numeric(
        raw,
        [
            "Swappiness",
            "Repeat",
            "Req/sec",
            "Failed",
            "p95_ms",
            "p99_ms",
            "delta_pgmajfault",
            "delta_pswpin",
            "delta_pswpout",
            "Slowdown",
        ],
    )
    agg = ensure_numeric(
        agg,
        [
            "Swappiness",
            "repeats",
            "req_sec_mean",
            "req_sec_std",
            "failed_mean",
            "p95_ms_mean",
            "p99_ms_mean",
            "delta_pgmajfault_mean",
            "delta_pswpin_mean",
            "delta_pswpout_mean",
            "slowdown_mean",
            "slowdown_std",
        ],
    )

    raw_stressed = raw[raw["Stress"] != "baseline"].copy()
    raw_stressed["Stress"] = pd.Categorical(raw_stressed["Stress"], categories=STRESS_ORDER, ordered=True)
    agg["Stress"] = pd.Categorical(agg["Stress"], categories=STRESS_ORDER, ordered=True)

    baseline = raw[raw["Stress"] == "baseline"]
    baseline_rps = float(baseline["Req/sec"].iloc[0]) if not baseline.empty else np.nan
    baseline_p95 = float(baseline["p95_ms"].iloc[0]) if not baseline.empty else np.nan
    baseline_p99 = float(baseline["p99_ms"].iloc[0]) if not baseline.empty else np.nan

    return (
        raw_stressed.sort_values(["Stress", "Swappiness", "Repeat"]),
        agg.sort_values(["Stress", "Swappiness"]),
        legacy,
        baseline_rps,
        baseline_p95,
        baseline_p99,
    )


def plot_slowdown_vs_swappiness(agg, outdir):
    plt.figure(figsize=(8, 5))
    for stress in STRESS_ORDER:
        sub = agg[agg["Stress"] == stress].sort_values("Swappiness")
        if sub.empty:
            continue
        plt.errorbar(
            sub["Swappiness"],
            sub["slowdown_mean"],
            yerr=sub["slowdown_std"],
            marker="o",
            capsize=4,
            label=stress,
        )
    plt.axhline(1.0, linestyle="--", linewidth=1, color="gray")
    plt.xlabel("Swappiness")
    plt.ylabel("Slowdown (baseline / contended)")
    plt.title("KVM Slowdown vs Swappiness by Stress Level")
    plt.legend(title="Stress")
    plt.tight_layout()
    plt.savefig(outdir / "kvm_slowdown_vs_swappiness.png", dpi=200)
    plt.close()


def plot_throughput_vs_swappiness(agg, baseline_rps, outdir):
    plt.figure(figsize=(8, 5))
    for stress in STRESS_ORDER:
        sub = agg[agg["Stress"] == stress].sort_values("Swappiness")
        if sub.empty:
            continue
        plt.errorbar(
            sub["Swappiness"],
            sub["req_sec_mean"],
            yerr=sub["req_sec_std"],
            marker="o",
            capsize=4,
            label=stress,
        )
    if np.isfinite(baseline_rps):
        plt.axhline(baseline_rps, linestyle="--", linewidth=1.2, color="black", label=f"baseline ({baseline_rps:.1f} rps)")
    plt.xlabel("Swappiness")
    plt.ylabel("Req/sec")
    plt.title("KVM Throughput vs Swappiness by Stress Level")
    plt.legend(title="Stress")
    plt.tight_layout()
    plt.savefig(outdir / "kvm_throughput_vs_swappiness.png", dpi=200)
    plt.close()


def plot_tail_latency(agg, baseline_p95, baseline_p99, outdir):
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.5), sharex=True)

    for stress in STRESS_ORDER:
        sub = agg[agg["Stress"] == stress].sort_values("Swappiness")
        if sub.empty:
            continue
        axes[0].plot(sub["Swappiness"], sub["p95_ms_mean"], marker="o", label=stress)
        axes[1].plot(sub["Swappiness"], sub["p99_ms_mean"], marker="o", label=stress)

    if np.isfinite(baseline_p95):
        axes[0].axhline(baseline_p95, linestyle="--", linewidth=1, color="gray")
    if np.isfinite(baseline_p99):
        axes[1].axhline(baseline_p99, linestyle="--", linewidth=1, color="gray")

    axes[0].set_title("p95 Latency vs Swappiness")
    axes[1].set_title("p99 Latency vs Swappiness")
    axes[0].set_ylabel("Latency (ms)")
    axes[0].set_xlabel("Swappiness")
    axes[1].set_xlabel("Swappiness")
    axes[0].legend(title="Stress")
    plt.suptitle("KVM Tail Latency Behavior")
    plt.tight_layout()
    plt.savefig(outdir / "kvm_tail_latency_vs_swappiness.png", dpi=200)
    plt.close()


def plot_raw_distribution(raw, outdir):
    plt.figure(figsize=(9, 5))
    if USE_SNS:
        sns.boxplot(data=raw, x="Stress", y="Slowdown", hue="Swappiness")
        sns.stripplot(data=raw, x="Stress", y="Slowdown", hue="Swappiness", dodge=True, alpha=0.45, linewidth=0.5, color="black")
        handles, labels = plt.gca().get_legend_handles_labels()
        n = len(sorted(raw["Swappiness"].dropna().unique()))
        plt.legend(handles[:n], labels[:n], title="Swappiness", bbox_to_anchor=(1.02, 1), loc="upper left")
    else:
        for idx, stress in enumerate(STRESS_ORDER):
            sample = raw[raw["Stress"] == stress]
            xs = np.full(len(sample), idx, dtype=float) + np.random.uniform(-0.15, 0.15, len(sample))
            plt.scatter(xs, sample["Slowdown"], alpha=0.7, s=35)
        plt.xticks(range(len(STRESS_ORDER)), STRESS_ORDER)
    plt.axhline(1.0, linestyle="--", linewidth=1, color="gray")
    plt.title("KVM Run-to-Run Slowdown Distribution")
    plt.ylabel("Slowdown")
    plt.xlabel("Stress")
    plt.tight_layout()
    plt.savefig(outdir / "kvm_slowdown_distribution_raw.png", dpi=200)
    plt.close()


def plot_heatmaps(agg, outdir):
    slowdown = agg.pivot(index="Stress", columns="Swappiness", values="slowdown_mean").reindex(STRESS_ORDER)
    p99 = agg.pivot(index="Stress", columns="Swappiness", values="p99_ms_mean").reindex(STRESS_ORDER)

    fig, axes = plt.subplots(1, 2, figsize=(12, 4.5))
    if USE_SNS:
        sns.heatmap(slowdown, annot=True, fmt=".2f", cmap="YlOrRd", ax=axes[0])
        sns.heatmap(p99, annot=True, fmt=".1f", cmap="Blues", ax=axes[1])
    else:
        im1 = axes[0].imshow(slowdown.values, aspect="auto")
        im2 = axes[1].imshow(p99.values, aspect="auto")
        fig.colorbar(im1, ax=axes[0])
        fig.colorbar(im2, ax=axes[1])
        axes[0].set_yticks(range(len(slowdown.index)))
        axes[0].set_yticklabels(slowdown.index)
        axes[0].set_xticks(range(len(slowdown.columns)))
        axes[0].set_xticklabels(slowdown.columns)
        axes[1].set_yticks(range(len(p99.index)))
        axes[1].set_yticklabels(p99.index)
        axes[1].set_xticks(range(len(p99.columns)))
        axes[1].set_xticklabels(p99.columns)

    axes[0].set_title("KVM Mean Slowdown Heatmap")
    axes[1].set_title("KVM Mean p99 Latency Heatmap (ms)")
    axes[0].set_xlabel("Swappiness")
    axes[1].set_xlabel("Swappiness")
    axes[0].set_ylabel("Stress")
    axes[1].set_ylabel("Stress")
    plt.tight_layout()
    plt.savefig(outdir / "kvm_heatmaps_slowdown_p99.png", dpi=220)
    plt.close()


def main():
    parser = argparse.ArgumentParser(description="Generate plots from KVM experiment summaries.")
    parser.add_argument("--raw", default="kvm_experiments/summary_runs_raw.csv")
    parser.add_argument("--agg", default="kvm_experiments/summary_aggregated.csv")
    parser.add_argument(
        "--legacy",
        default="kvm_experiments/corr_rt_30_timeout_600_with_slowdown_global_baseline_linux_kvm.csv",
    )
    parser.add_argument("--outdir", default="kvm_experiments/plots")
    args = parser.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    raw, agg, legacy, baseline_rps, baseline_p95, baseline_p99 = load_inputs(args.raw, args.agg, args.legacy)

    plot_slowdown_vs_swappiness(agg, outdir)
    plot_throughput_vs_swappiness(agg, baseline_rps, outdir)
    plot_tail_latency(agg, baseline_p95, baseline_p99, outdir)
    plot_raw_distribution(raw, outdir)
    plot_heatmaps(agg, outdir)

    print(f"Wrote plots to: {outdir.resolve()}")
    print(f"Rows loaded: raw={len(raw)} agg={len(agg)} legacy={len(legacy)}")


if __name__ == "__main__":
    main()
