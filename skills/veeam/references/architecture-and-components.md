# Architecture & Components

## Component Map

```text
                    ┌────────────────────┐
 hypervisors ──────▶│  backup proxies    │──▶ repositories (SMB/Linux/Hardened)
 agents (servers) ─▶│  (data movers)     │──▶ object storage (S3-compatible, immutable)
 NAS/file shares ──▶│                    │──▶ tape (if used)
                    └───────┬────────────┘
                            │
                    backup server (config + catalog + job scheduler)
                            │
                 Veeam ONE / Enterprise Manager (monitoring, self-service)
```

| Component | Role |
|-----------|------|
| **Backup server** | Windows host running the B&R server: job scheduling, catalog (SQL), coordination |
| **Backup proxy** | Data mover: reads VM disks, deduplicates/compresses, writes to repository |
| **Repository** | Target storage (Windows/Linux share, Linux hardened, object storage) |
| **WAN accelerator** | Optional WAN dedupe for offsite copies |
| **Mount server** | File-level restore plumbing |
| **Enterprise Manager / ONE** | Self-service portal / monitoring & reporting |

## Proxy Modes (how disks are read)

| Mode | Mechanism | Notes |
|------|-----------|-------|
| **Hot Add** | Disk attached to proxy VM over storage | No load on hosts; needs storage I/O; recommended default for vSphere |
| **Virtual Appliance** (VADP) | Snapshot-based read via ESXi | Legacy; host overhead |
| **Network (NBD)** | Read over network from ESXi | Simplest, slowest, host network load |

Sizing rule: one proxy core handles ~2-4 concurrent VM tasks (hot-add);
`max tasks` per proxy × proxies = parallelism. Start with one proxy per
~10-20 concurrent tasks target and measure.

## Repositories

| Type | Traits |
|------|--------|
| Windows/SMB share | Simple; ACL-protected; ransomware-vulnerable without extra care |
| **Linux hardened** | XFS + reflinks, single-use credentials, immutability — the ransomware answer |
| **Object storage (S3)** | Capacity tier / archive; S3 Object Lock for immutability |
| Deduplicating appliance | Vendor-specific integration |

**SOBR (Scale-Out Backup Repository)** aggregates multiple extents into one
logical repository with policies (data locality, performance tiers) and optional
copy-to-object tier. SOBR + immutable capacity tier is the modern baseline.

## Data Flow (what actually happens per VM)

```text
VM → snapshot (hypervisor) → proxy reads changed blocks (CBT) →
compress/dedupe → repository writes .vbk (full) + .vrb/.vib (increments)
backup copy job re-reads repo → pushes to secondary/immutable target
```

- **Incremental forever**: one initial full (`vbk`), forever-incrementals merged
  at read time; retention prunes restore points.
- Changed-block tracking (CBT) makes increments proportional to churn — verify
  CBT works or backups crawl.

## Backup Server Sizing

- The backup server is the control plane: keep it off the data path (use
  dedicated proxies).
- Catalog/config DB grows with restore points and objects; put the SQL instance
  on fast local storage, back it up (configuration backup is built-in — enable
  automatic config backup with encryption).
- One backup server per environment scale (~few thousand VMs guidance); scale by
  adding proxies/repositories, not by growing the single box.

## Anti-Patterns at Architecture Level

1. Backup server doubling as proxy (data path + control plane coupled).
2. Repository on the same storage as production (a storage failure kills both).
3. No immutable/offsite second copy — 3-2-1-1-0 broken at the architecture level.
4. Proxy oversubscription: jobs queue because one proxy carries all tasks.
5. Dedupe appliances as the only copy (rehydration pain at restore time).
