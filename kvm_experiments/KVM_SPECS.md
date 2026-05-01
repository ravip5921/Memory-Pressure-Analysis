lscpu
Architecture:             x86_64
  CPU op-mode(s):         32-bit, 64-bit
  Address sizes:          39 bits physical, 48 bits virtual
  Byte Order:             Little Endian
CPU(s):                   2
  On-line CPU(s) list:    0,1
Vendor ID:                GenuineIntel
  Model name:             Intel(R) Core(TM) i7-7700T CPU @ 2.90GHz
    CPU family:           6
    Model:                158
    Thread(s) per core:   1
    Core(s) per socket:   1
    Socket(s):            2
    Stepping:             9
    BogoMIPS:             5807.94
    Flags:                fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ss syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon rep_good nopl xtopolog
                          y cpuid tsc_known_freq pni pclmulqdq vmx ssse3 fma cx16 pdcm pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand hypervisor lahf_lm abm 3dnowprefe
                          tch cpuid_fault invpcid_single pti ssbd ibrs ibpb stibp tpr_shadow vnmi flexpriority ept vpid ept_ad fsgsbase tsc_adjust bmi1 avx2 smep bmi2 erms invpcid mpx rdseed adx smap clfl
                          ushopt xsaveopt xsavec xgetbv1 xsaves arat umip md_clear arch_capabilities
Virtualization features:  
  Virtualization:         VT-x
  Hypervisor vendor:      KVM
  Virtualization type:    full
Caches (sum of all):      
  L1d:                    64 KiB (2 instances)
  L1i:                    64 KiB (2 instances)
  L2:                     8 MiB (2 instances)
  L3:                     32 MiB (2 instances)
NUMA:                     
  NUMA node(s):           1
  NUMA node0 CPU(s):      0,1
Vulnerabilities:          
  Gather data sampling:   Unknown: Dependent on hypervisor status
  Itlb multihit:          Not affected
  L1tf:                   Mitigation; PTE Inversion; VMX flush not necessary, SMT disabled
  Mds:                    Mitigation; Clear CPU buffers; SMT Host state unknown
  Meltdown:               Mitigation; PTI
  Mmio stale data:        Vulnerable: Clear CPU buffers attempted, no microcode; SMT Host state unknown
  Reg file data sampling: Not affected
  Retbleed:               Mitigation; IBRS
  Spec rstack overflow:   Not affected
  Spec store bypass:      Mitigation; Speculative Store Bypass disabled via prctl and seccomp
  Spectre v1:             Mitigation; usercopy/swapgs barriers and __user pointer sanitization
  Spectre v2:             Mitigation; IBRS; IBPB conditional; STIBP disabled; RSB filling; PBRSB-eIBRS Not affected; BHI SW loop, KVM SW loop
  Srbds:                  Unknown: Dependent on hypervisor status
  Tsx async abort:        Not affected
ubuntu-server@ubuntu-server:~/Memory-Pressure-Analysis$ cat /proc/meminfo
MemTotal:        4005820 kB
MemFree:         1477080 kB
MemAvailable:    2531480 kB
Buffers:            9608 kB
Cached:          2085288 kB
SwapCached:            0 kB
Active:           646936 kB
Inactive:        1618648 kB
Active(anon):     360740 kB
Inactive(anon):   685584 kB
Active(file):     286196 kB
Inactive(file):   933064 kB
Unevictable:       27620 kB
Mlocked:           27620 kB
SwapTotal:             0 kB
SwapFree:              0 kB
Dirty:                 0 kB
Writeback:             0 kB
AnonPages:        198428 kB
Mapped:            95708 kB
Shmem:            869960 kB
KReclaimable:      87248 kB
Slab:             142912 kB
SReclaimable:      87248 kB
SUnreclaim:        55664 kB
KernelStack:        2528 kB
PageTables:         2620 kB
NFS_Unstable:          0 kB
Bounce:                0 kB
WritebackTmp:          0 kB
CommitLimit:     2002908 kB
Committed_AS:    1445256 kB
VmallocTotal:   34359738367 kB
VmallocUsed:       17468 kB
VmallocChunk:          0 kB
Percpu:             1288 kB
HardwareCorrupted:     0 kB
AnonHugePages:         0 kB
ShmemHugePages:        0 kB
ShmemPmdMapped:        0 kB
FileHugePages:         0 kB
FilePmdMapped:         0 kB
HugePages_Total:       0
HugePages_Free:        0
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:       2048 kB
Hugetlb:               0 kB
DirectMap4k:      122736 kB
DirectMap2M:     4071424 kB
DirectMap1G:     2097152 kB
ubuntu-server@ubuntu-server:~/Memory-Pressure-Analysis$ 