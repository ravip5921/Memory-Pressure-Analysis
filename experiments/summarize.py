import os
import re
import pandas as pd

BASE = "results"
BASELINE_DIR = "results/baseline"

rows = []

# ---- Parse baseline ----
baseline_rps = None  # single global baseline


ab_file = os.path.join(BASELINE_DIR, "ab.txt")
with open(ab_file) as f:
    ab_text = f.read()
baseline_rps = float(re.search(r"Requests per second:\s+([\d\.]+)", ab_text).group(1))

# Parse vmstat
def parse_vmstat(file):
    d = {}
    with open(file) as f:
        for line in f:
            k, v = line.split()
            d[k] = int(v)
    return d

before = parse_vmstat(os.path.join(BASELINE_DIR, "vmstat_before.txt"))
after = parse_vmstat(os.path.join(BASELINE_DIR, "vmstat_after.txt"))

delta_pgmaj = after["pgmajfault"] - before["pgmajfault"]
delta_pswpin = after["pswpin"] - before["pswpin"]
delta_pswpout = after["pswpout"] - before["pswpout"]

# Add baseline row
rows.append([
    "baseline", "baseline", baseline_rps, 0,
    delta_pgmaj, delta_pswpin, delta_pswpout,
    1.0  # slowdown for baseline
])

# ---- Parse all other runs ----
for d in os.listdir(BASE):
    path = os.path.join(BASE, d)
    if not os.path.isdir(path) or d.startswith("baseline"):
        continue

    swap = d.split("_")[1]
    level = d.split("_")[2]

    ab_file = os.path.join(path, "ab.txt")
    with open(ab_file) as f:
        ab_text = f.read()
    rps = float(re.search(r"Requests per second:\s+([\d\.]+)", ab_text).group(1))
    failed = int(re.search(r"Failed requests:\s+(\d+)", ab_text).group(1))

    # Parse vmstat
    def parse_vmstat(file):
        d = {}
        with open(file) as f:
            for line in f:
                k, v = line.split()
                d[k] = int(v)
        return d

    before = parse_vmstat(os.path.join(path, "vmstat_before.txt"))
    after = parse_vmstat(os.path.join(path, "vmstat_after.txt"))

    delta_pgmaj = after["pgmajfault"] - before["pgmajfault"]
    delta_pswpin = after["pswpin"] - before["pswpin"]
    delta_pswpout = after["pswpout"] - before["pswpout"]

    # Slowdown relative to single global baseline
    slowdown = baseline_rps / rps if baseline_rps else None

    rows.append([
        swap, level, rps, failed,
        delta_pgmaj, delta_pswpin, delta_pswpout,
        slowdown
    ])

# ---- Create dataframe ----
df = pd.DataFrame(rows, columns=[
    "Swappiness",
    "Stress",
    "Req/sec",
    "Failed",
    "Δpgmajfault",
    "Δpswpin",
    "Δpswpout",
    "Slowdown"
])

df = df.sort_values(["Swappiness", "Stress"])
print(df.to_string(index=False))

df.to_csv("corr_rt_30_timeout_600_with_slowdown_global_baseline.csv", index=False)