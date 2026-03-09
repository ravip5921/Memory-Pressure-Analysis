### Running Stress tests under interference: run_docker_interference_c1_only.sh

Runs failed. 
Excepted
Reasoning:
To evaluate the impact of memory contention on containerized workloads, we conducted a latency benchmark using ApacheBench against a service container constrained to 512 MB of memory. The experiment consisted of two configurations: a baseline scenario where the service container ran in isolation, and a contended scenario where an additional container generated memory pressure using stress-ng by allocating approximately 600 MB of virtual memory. During the contended execution, the benchmark exhibited connection resets and request timeouts, resulting in fewer completed requests than the intended workload. These behaviors indicate that memory interference from the co-located stress container degraded the responsiveness and stability of the latency-sensitive service. The observed failures suggest that increased memory pressure likely triggered kernel memory reclamation or out-of-memory handling, thereby disrupting normal request processing within the service container.

### Running Stress tests under interference: run_docker_interference_c1_only.sh with increased time out [-s 60 in ab runs]

Runs completed.

Under the contended configuration, ApacheBench initially reported connection resets and request timeouts. After increasing the benchmark timeout parameter, the experiment completed successfully but with significantly reduced throughput. The isolated configuration achieved 2133.53 requests/sec, whereas the contended configuration achieved 1376.75 requests/sec, corresponding to a proportional slowdown of 1.55×. This degradation suggests substantial memory interference between co-located containers. The failures observed under default timeout settings indicate that memory pressure introduced latency spikes severe enough to disrupt request completion, likely due to kernel-level reclaim activity or swap-induced stalls.


### Running Stress tests under interference: run_docker_interference.sh

## Memory Interference Experiment Results

We evaluated the impact of co-located memory-intensive workloads on a latency-sensitive service container (C1) by running it alone (baseline) and alongside a stress container (C2) that allocated 600 MB of anonymous memory. System and container memory statistics were collected before and after the benchmarks, along with ApacheBench measurements to capture service throughput.

Under contention, the stress container caused significant swap activity (`pswpout = 82944`), and memory reclamation was almost entirely for anonymous pages (`pgsteal_anon = 22200`, `pgsteal_file = 0`). Despite this pressure, the service container experienced only minimal major page faults (`pgmajfault = 3`) and a small performance slowdown (~5% in requests per second). No out-of-memory (OOM) events were observed, and the service did not suffer disproportionately compared to the stress container.

These results demonstrate that while memory-intensive workloads can trigger swapping and anonymous page reclaim at the host level, a well-provisioned service container may continue to operate reliably with minor performance degradation. This highlights the importance of monitoring memory contention in multi-tenant container environments and informs strategies for isolation and resource allocation in our project.