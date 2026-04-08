import re
from pathlib import Path

import pandas as pd


SCRIPT_DIR = Path(__file__).resolve().parent
BASE = SCRIPT_DIR / "results"
BASELINE_DIR = BASE / "baseline"

RAW_OUT = SCRIPT_DIR / "summary_runs_raw.csv"
AGG_OUT = SCRIPT_DIR / "summary_aggregated.csv"
LEGACY_OUT = SCRIPT_DIR / "corr_rt_30_timeout_600_with_slowdown_global_baseline_linux_kvm.csv"


def parse_manifest(path: Path) -> dict:
    data = {}
    if not path.exists():
        return data
    for line in path.read_text().splitlines():
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        data[k.strip()] = v.strip()
    return data


def parse_vmstat(path: Path) -> dict:
    values = {}
    for line in path.read_text().splitlines():
        parts = line.split()
        if len(parts) == 2:
            values[parts[0]] = int(parts[1])
    return values


def parse_ab_metrics(path: Path) -> dict:
    text = path.read_text()

    def match_float(pattern: str):
        m = re.search(pattern, text, flags=re.MULTILINE)
        return float(m.group(1)) if m else None

    def match_int(pattern: str):
        m = re.search(pattern, text, flags=re.MULTILINE)
        return int(m.group(1)) if m else None

    return {
        "rps": match_float(r"Requests per second:\s+([\d\.]+)"),
        "failed": match_int(r"Failed requests:\s+(\d+)"),
        "p95_ms": match_float(r"^\s*95%\s+([\d\.]+)"),
        "p99_ms": match_float(r"^\s*99%\s+([\d\.]+)"),
    }


if not BASELINE_DIR.exists():
    raise FileNotFoundError(f"Missing baseline directory: {BASELINE_DIR}")

baseline_ab = parse_ab_metrics(BASELINE_DIR / "ab.txt")
if baseline_ab["rps"] is None:
    raise ValueError("Could not parse baseline Requests per second from baseline/ab.txt")

baseline_manifest = parse_manifest(BASELINE_DIR / "manifest.txt")
baseline_before = parse_vmstat(BASELINE_DIR / "vmstat_before.txt")
baseline_after = parse_vmstat(BASELINE_DIR / "vmstat_after.txt")
baseline_rps = baseline_ab["rps"]

rows = []

rows.append(
    {
        "Swappiness": "baseline",
        "Stress": "baseline",
        "Repeat": 1,
        "Req/sec": baseline_rps,
        "Failed": baseline_ab["failed"] if baseline_ab["failed"] is not None else 0,
        "p95_ms": baseline_ab["p95_ms"],
        "p99_ms": baseline_ab["p99_ms"],
        "delta_pgmajfault": baseline_after.get("pgmajfault", 0)
        - baseline_before.get("pgmajfault", 0),
        "delta_pswpin": baseline_after.get("pswpin", 0) - baseline_before.get("pswpin", 0),
        "delta_pswpout": baseline_after.get("pswpout", 0) - baseline_before.get("pswpout", 0),
        "Slowdown": 1.0,
        "baseline_mode": baseline_manifest.get("baseline_mode", "single_global"),
        "baseline_swappiness": baseline_manifest.get("baseline_swappiness", "unknown"),
        "ab_concurrency": baseline_manifest.get("ab_concurrency", "unknown"),
        "run_timestamp": baseline_manifest.get("run_timestamp", "unknown"),
        "platform": "kvm",
    }
)

pattern = re.compile(r"^swap_(\d+)_(moderate|high|extreme)_r(\d+)$")

for child in sorted(BASE.iterdir()):
    if not child.is_dir() or child.name == "baseline":
        continue

    m = pattern.match(child.name)
    if not m:
        continue

    swap, level, rep = m.groups()

    ab = parse_ab_metrics(child / "ab.txt")
    before = parse_vmstat(child / "vmstat_before.txt")
    after = parse_vmstat(child / "vmstat_after.txt")
    manifest = parse_manifest(child / "manifest.txt")

    if ab["rps"] is None:
        continue

    rows.append(
        {
            "Swappiness": int(swap),
            "Stress": level,
            "Repeat": int(rep),
            "Req/sec": ab["rps"],
            "Failed": ab["failed"] if ab["failed"] is not None else 0,
            "p95_ms": ab["p95_ms"],
            "p99_ms": ab["p99_ms"],
            "delta_pgmajfault": after.get("pgmajfault", 0) - before.get("pgmajfault", 0),
            "delta_pswpin": after.get("pswpin", 0) - before.get("pswpin", 0),
            "delta_pswpout": after.get("pswpout", 0) - before.get("pswpout", 0),
            "Slowdown": baseline_rps / ab["rps"],
            "baseline_mode": baseline_manifest.get("baseline_mode", "single_global"),
            "baseline_swappiness": baseline_manifest.get("baseline_swappiness", "unknown"),
            "ab_concurrency": manifest.get(
                "ab_concurrency",
                baseline_manifest.get("ab_concurrency", "unknown"),
            ),
            "run_timestamp": manifest.get("run_timestamp", "unknown"),
            "platform": "kvm",
        }
    )

raw_df = pd.DataFrame(rows)
raw_df = raw_df.sort_values(["Swappiness", "Stress", "Repeat"], na_position="last")
raw_df.to_csv(RAW_OUT, index=False)

stressed = raw_df[raw_df["Stress"] != "baseline"].copy()
agg_df = (
    stressed.groupby(["Swappiness", "Stress"], as_index=False)
    .agg(
        repeats=("Repeat", "count"),
        req_sec_mean=("Req/sec", "mean"),
        req_sec_std=("Req/sec", "std"),
        failed_mean=("Failed", "mean"),
        p95_ms_mean=("p95_ms", "mean"),
        p99_ms_mean=("p99_ms", "mean"),
        delta_pgmajfault_mean=("delta_pgmajfault", "mean"),
        delta_pswpin_mean=("delta_pswpin", "mean"),
        delta_pswpout_mean=("delta_pswpout", "mean"),
        slowdown_mean=("Slowdown", "mean"),
        slowdown_std=("Slowdown", "std"),
    )
    .sort_values(["Swappiness", "Stress"])
)

for key in ["baseline_mode", "baseline_swappiness", "ab_concurrency"]:
    agg_df[key] = baseline_manifest.get(key, "unknown")
agg_df["platform"] = "kvm"

agg_df.to_csv(AGG_OUT, index=False)
agg_df.to_csv(LEGACY_OUT, index=False)

print("Wrote:")
print(f"- {RAW_OUT}")
print(f"- {AGG_OUT}")
print(f"- {LEGACY_OUT}")
