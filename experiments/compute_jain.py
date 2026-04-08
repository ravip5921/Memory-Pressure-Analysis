#!/usr/bin/env python3
"""
Compute Jain's Fairness Index from ApacheBench outputs saved in experiment result
directories.

Usage examples:

# Compute J for three workload directories (each must contain ab.txt):
python3 experiments/compute_jain.py results/workloadA results/workloadB results/workloadC \
  --baseline results/baseline

# Scan a parent directory and compute J between all child directories that have
# an ab.txt file, using a single baseline dir to normalize:
python3 experiments/compute_jain.py --scan experiments/results --baseline experiments/results/baseline

# If you already have solo baselines per workload put them in baseline/<workload>/ab.txt
# and call with the workload dirs as positional args and --baseline baseline_dir

The script prints per-workload RPS, normalized x = colocated/baseline, and the computed
Jain index. It also emits a CSV to stdout with columns: run, rps, baseline_rps, x

If a workload's baseline cannot be found the script will skip that workload unless
--require-baseline is not set (default: require baseline).

"""

import argparse
import os
import re
import sys
import math
import csv
from typing import Optional, Tuple, List

RPS_RE = re.compile(r"Requests per second:\s*([0-9]+\.?[0-9]*)", re.IGNORECASE)


def extract_rps_from_ab(ab_path: str) -> Optional[float]:
    """Extract Requests per second value from an ApacheBench (ab) output file."""
    if not os.path.isfile(ab_path):
        return None
    try:
        with open(ab_path, "r", encoding="utf-8", errors="ignore") as f:
            text = f.read()
    except Exception:
        return None
    m = RPS_RE.search(text)
    if m:
        try:
            return float(m.group(1))
        except ValueError:
            return None
    # Try alternate patterns (some ab builds show "Requests per second:    123.45 [#/sec] (mean)")
    alt = re.search(r"Requests per second:\s*([0-9]+\.?[0-9]*)", text, re.IGNORECASE)
    if alt:
        return float(alt.group(1))
    return None


def jain_index(xs: List[float]) -> float:
    xs = [float(x) for x in xs]
    n = len(xs)
    if n == 0:
        return 0.0
    s = sum(xs)
    ss = sum(x * x for x in xs)
    if ss == 0:
        return 0.0
    return (s * s) / (n * ss)


def find_baseline_for_workload(baseline_dir: str, workload_name: str) -> Optional[str]:
    """Look for a baseline ab.txt for a workload. Preferred locations (in order):
    - baseline_dir/<workload_name>/ab.txt
    - baseline_dir/ab.txt
    - baseline_dir/<workload_name>_ab.txt
    Returns path or None.
    """
    # 1
    p1 = os.path.join(baseline_dir, workload_name, "ab.txt")
    if os.path.isfile(p1):
        return p1
    # 2
    p2 = os.path.join(baseline_dir, "ab.txt")
    if os.path.isfile(p2):
        return p2
    # 3
    p3 = os.path.join(baseline_dir, f"{workload_name}_ab.txt")
    if os.path.isfile(p3):
        return p3
    return None


def workload_name_from_path(path: str) -> str:
    return os.path.basename(os.path.normpath(path))


def main(argv=None):
    parser = argparse.ArgumentParser(description="Compute Jain's Fairness from ab outputs")
    parser.add_argument("workloads", nargs="*",
                        help="Paths to workload result directories (each should contain ab.txt).")
    parser.add_argument("--scan", "-s", help="Scan a directory and use each immediate child that contains ab.txt as a workload")
    parser.add_argument("--baseline", "-b",
                        help="Path to baseline directory (either contains ab.txt or per-workload subdirs with ab.txt)."
                             " If omitted and --scan is used, the script will attempt to find baseline dirs"
                             " named with the --baseline-prefix under the same parent (e.g. baseline_<workload>)")
    parser.add_argument("--baseline-prefix", default="baseline_",
                        help="Prefix used for baseline directories when baselines live alongside workload dirs (default: 'baseline_').")
    parser.add_argument("--require-baseline", action="store_true", default=False,
                        help="If set, skip workloads that do not have a matching baseline. If not set, workloads without baseline are skipped anyway.")
    parser.add_argument("--out-csv", help="Write CSV output to this file (default: stdout)")
    args = parser.parse_args(argv)

    workloads = list(args.workloads)
    if args.scan:
        if not os.path.isdir(args.scan):
            print(f"Scan path {args.scan} is not a directory", file=sys.stderr)
            sys.exit(2)
        for name in sorted(os.listdir(args.scan)):
            # Skip baseline directories when enumerating workloads; baselines are
            # expected to be named with the baseline prefix (e.g. 'baseline_...').
            if name.startswith(args.baseline_prefix):
                continue
            child = os.path.join(args.scan, name)
            if os.path.isdir(child):
                ab = os.path.join(child, "ab.txt")
                if os.path.isfile(ab):
                    workloads.append(child)
    if not workloads:
        print("No workloads supplied or found (use positional paths or --scan).", file=sys.stderr)
        parser.print_help()
        sys.exit(2)

    rows = []  # rows for CSV: workload, workload_ab_path, rps, baseline_ab_path, baseline_rps, x
    xs = []

    for w in workloads:
        ab_path = os.path.join(w, "ab.txt")
        rps = extract_rps_from_ab(ab_path)
        wname = workload_name_from_path(w)
        if rps is None:
            print(f"Warning: could not extract RPS from {ab_path}; skipping workload {wname}", file=sys.stderr)
            continue
        # find baseline
        bpath = None
        # 1) If a baseline directory was explicitly provided, try to find matching baseline there
        if args.baseline:
            if os.path.isdir(args.baseline):
                bpath = find_baseline_for_workload(args.baseline, wname)
            else:
                # allow pointing directly to a baseline file
                if os.path.isfile(args.baseline):
                    bpath = args.baseline
        # 2) If not found and we scanned a parent where baselines live alongside workloads,
        #    try to find a sibling baseline directory named with the configured prefix.
        if bpath is None and args.scan:
            parent = os.path.dirname(os.path.normpath(args.scan))
            # If scan was a parent (e.g., experiments/results), workloads are child dirs under scan
            # Build expected baseline path: <scan>/<baseline_prefix><workload_name>
            candidate = os.path.join(args.scan, args.baseline_prefix + wname)
            candidate_ab = os.path.join(candidate, "ab.txt")
            if os.path.isfile(candidate_ab):
                bpath = candidate_ab
            else:
                # Try baseline file naming convention: baseline_<workload>_ab.txt directly under scan
                candidate2 = os.path.join(args.scan, f"{args.baseline_prefix}{wname}_ab.txt")
                if os.path.isfile(candidate2):
                    bpath = candidate2
        if bpath is None:
            print(f"Warning: baseline for workload {wname} not found; skipping", file=sys.stderr)
            if args.require_baseline:
                continue
            else:
                continue
        brps = extract_rps_from_ab(bpath)
        if brps is None or brps == 0:
            print(f"Warning: could not extract RPS from baseline {bpath} for workload {wname}; skipping", file=sys.stderr)
            continue
        x = rps / brps
        rows.append((wname, ab_path, rps, bpath, brps, x))
        xs.append(x)

    if not rows:
        print("No valid workloads processed—no output.", file=sys.stderr)
        sys.exit(1)

    J = jain_index(xs)

    # Print summary
    print("workload,workload_ab,workload_rps,baseline_ab,baseline_rps,normalized_x")
    for r in rows:
        # r: (wname, ab_path, rps, bpath, brps, x)
        print(f"{r[0]},{r[1]},{r[2]:.3f},{r[3]},{r[4]:.3f},{r[5]:.6f}")
    print()
    print(f"Jain's fairness index (n={len(xs)}): {J:.6f}")

    # Write CSV if requested
    if args.out_csv:
        try:
            with open(args.out_csv, "w", newline="") as csvf:
                writer = csv.writer(csvf)
                writer.writerow(["workload", "workload_ab", "workload_rps", "baseline_ab", "baseline_rps", "normalized_x"])
                for r in rows:
                    writer.writerow([r[0], r[1], f"{r[2]:.6f}", r[3], f"{r[4]:.6f}", f"{r[5]:.6f}"])
                writer.writerow(["jain", "", f"{J:.6f}", "", "", ""])
            print(f"Wrote CSV to {args.out_csv}")
        except Exception as e:
            print(f"Failed to write CSV: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
