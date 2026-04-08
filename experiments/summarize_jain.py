#!/usr/bin/env python3
"""Compute Jain's fairness index from the Docker experiment summaries and plot it.

This script treats each stress level within a given swappiness and repeat as a
set of competing measurements, then computes Jain's index over throughput and
inverse slowdown. The main output is a fairness-vs-swappiness plot plus CSVs
with raw and aggregated values.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt


STRESS_ORDER = ["moderate", "high", "extreme"]


def jain_index(values: pd.Series | list[float]) -> float:
    series = pd.to_numeric(pd.Series(values), errors="coerce").dropna()
    series = series[series > 0]
    if series.empty:
        return float("nan")
    numerator = float(series.sum()) ** 2
    denominator = float(len(series)) * float((series ** 2).sum())
    return numerator / denominator if denominator else float("nan")


def load_raw(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    required = ["Swappiness", "Stress", "Repeat", "Req/sec", "Slowdown"]
    missing = [col for col in required if col not in df.columns]
    if missing:
        raise ValueError(f"Missing required columns in {path}: {', '.join(missing)}")
    df = df[df["Stress"] != "baseline"].copy()
    df["Swappiness"] = pd.to_numeric(df["Swappiness"], errors="coerce")
    df["Repeat"] = pd.to_numeric(df["Repeat"], errors="coerce")
    df["Req/sec"] = pd.to_numeric(df["Req/sec"], errors="coerce")
    df["Slowdown"] = pd.to_numeric(df["Slowdown"], errors="coerce")
    df["Stress"] = pd.Categorical(df["Stress"], categories=STRESS_ORDER, ordered=True)
    return df.sort_values(["Swappiness", "Repeat", "Stress"])


def compute_raw_jain(df: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for (swappiness, repeat), group in df.groupby(["Swappiness", "Repeat"], dropna=True):
        stress_group = group.set_index("Stress").reindex(STRESS_ORDER)
        throughput_vals = stress_group["Req/sec"].tolist()
        inverse_slowdown_vals = (1.0 / stress_group["Slowdown"]).replace([np.inf, -np.inf], np.nan).tolist()

        rows.append(
            {
                "Swappiness": int(swappiness),
                "Repeat": int(repeat),
                "jain_throughput": jain_index(throughput_vals),
                "jain_inverse_slowdown": jain_index(inverse_slowdown_vals),
                "throughput_min": pd.to_numeric(stress_group["Req/sec"], errors="coerce").min(),
                "throughput_max": pd.to_numeric(stress_group["Req/sec"], errors="coerce").max(),
                "slowdown_min": pd.to_numeric(stress_group["Slowdown"], errors="coerce").min(),
                "slowdown_max": pd.to_numeric(stress_group["Slowdown"], errors="coerce").max(),
            }
        )

    raw = pd.DataFrame(rows)
    return raw.sort_values(["Swappiness", "Repeat"])


def compute_aggregated_jain(raw: pd.DataFrame) -> pd.DataFrame:
    agg = (
        raw.groupby("Swappiness", as_index=False)
        .agg(
            repeats=("Repeat", "count"),
            jain_throughput_mean=("jain_throughput", "mean"),
            jain_throughput_std=("jain_throughput", "std"),
            jain_inverse_slowdown_mean=("jain_inverse_slowdown", "mean"),
            jain_inverse_slowdown_std=("jain_inverse_slowdown", "std"),
            throughput_min=("throughput_min", "mean"),
            throughput_max=("throughput_max", "mean"),
            slowdown_min=("slowdown_min", "mean"),
            slowdown_max=("slowdown_max", "mean"),
        )
        .sort_values("Swappiness")
    )
    return agg


def plot_jain(agg: pd.DataFrame, outdir: Path) -> None:
    plt.figure(figsize=(8, 5))
    plt.errorbar(
        agg["Swappiness"],
        agg["jain_throughput_mean"],
        yerr=agg["jain_throughput_std"],
        marker="o",
        capsize=4,
        label="Throughput Jain index",
    )
    plt.errorbar(
        agg["Swappiness"],
        agg["jain_inverse_slowdown_mean"],
        yerr=agg["jain_inverse_slowdown_std"],
        marker="s",
        capsize=4,
        label="Inverse-slowdown Jain index",
    )
    plt.ylim(0.0, 1.05)
    plt.xlabel("Swappiness")
    plt.ylabel("Jain's fairness index")
    plt.title("Fairness Across Stress Levels by Swappiness")
    plt.legend()
    plt.tight_layout()
    plt.savefig(outdir / "jain_fairness_vs_swappiness.png", dpi=200)
    plt.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Compute Jain's fairness index and plot it.")
    parser.add_argument("--raw", default="experiments/summary_runs_raw.csv", help="Path to raw summary CSV")
    parser.add_argument("--outdir", default="experiments/plots", help="Directory for generated plots")
    parser.add_argument("--raw-out", default="experiments/jain_summary_raw.csv", help="Path for raw Jain summary CSV")
    parser.add_argument("--agg-out", default="experiments/jain_summary_aggregated.csv", help="Path for aggregated Jain CSV")
    args = parser.parse_args()

    raw_path = Path(args.raw)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    raw = load_raw(raw_path)
    raw_jain = compute_raw_jain(raw)
    agg_jain = compute_aggregated_jain(raw_jain)

    raw_out = Path(args.raw_out)
    agg_out = Path(args.agg_out)
    raw_jain.to_csv(raw_out, index=False)
    agg_jain.to_csv(agg_out, index=False)

    plot_jain(agg_jain, outdir)

    print(f"Wrote raw Jain summary to: {raw_out.resolve()}")
    print(f"Wrote aggregated Jain summary to: {agg_out.resolve()}")
    print(f"Wrote Jain plot to: {outdir.resolve() / 'jain_fairness_vs_swappiness.png'}")


if __name__ == "__main__":
    main()