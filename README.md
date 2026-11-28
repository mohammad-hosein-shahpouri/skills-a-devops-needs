# Agent Skills Repository

A modular collection of specialized skills designed for AI agents (Antigravity, Claude Code, Cursor, and other agent frameworks).

## Cloning & Updating

This repository contains submodules (e.g. `skills/gitlab-ci`). To ensure all skills are automatically fetched and kept in sync:

```bash
# Clone with all skills:
git clone --recurse-submodules <repo-url>

# Or enable automatic submodule recursion on your machine:
git config --global submodule.recurse true
```

Whenever you run `git pull` in this repository, Git will automatically update all submodules.

## How to Install & Use Skills

Skills in this repository follow the open **Agent Skill specification** (`SKILL.md` with YAML frontmatter `name` and `description`, accompanied by `references/` and `examples/`). They are compatible with all modern AI agent frameworks through progressive disclosure.

Just ask your agent to install these skills from this repo and go on.

---

## Skills Directory

### [Ansible](./skills/ansible/SKILL.md)

Comprehensive reference for Ansible and ansible-core — agentless IT automation, configuration management, playbooks, roles, collections, and execution environments.

#### Coverage

- **Architecture & Config**: Control vs managed nodes, `pipx`/`pip` installation, `ansible.cfg` precedence, and core configuration settings.
- **Inventory & Transport**: INI and YAML inventories, ranges, group nesting (`:children`), `host_vars`/`group_vars`, behavioral connection variables, and pattern targeting.
- **Playbooks & Execution**: YAML rules, keywords, loops (`loop`/`loop_control`), conditionals (`when`), handlers (`notify`/`listen`), blocks/rescue/always, and tags (`always`/`never`).
- **Variables & Precedence**: Complete 22-level precedence hierarchy, registered variables, common return values (`changed`, `failed`, `rc`), and special/magic variables.
- **Roles & Collections**: Directory layout, `meta/argument_specs.yml`, static vs dynamic reuse, FQCN resolution, `requirements.yml`, and `collections:` search paths.
- **Plugins & Modules**: 8 major plugin types (Action, Callback, Connection, Filter, Lookup, Strategy, Test, Vars), `ansible-doc`, and lookup/filter expressions.
- **Vault & Security**: AES-256 encryption at rest, file vs variable (`!vault |`) encryption, `--vault-id` labels, multi-vault passwords, and client scripts.
- **Execution Environments & Windows**: `execution-environment.yml` v3, `ansible-builder`, `ansible-navigator`, Windows management (WinRM/PSRP/SSH), and performance tuning (forks, pipelining, async/poll).

---

### [CloudNativePG (CNPG) v1.30](./skills/cloudnative-pg/SKILL.md)

Comprehensive architecture guides, declarative configurations, and operational runbooks for running PostgreSQL clusters on Kubernetes using CloudNativePG v1.30.

#### Coverage

- **Architecture**: PID 1 Instance Manager, Primary Lease (serialized promotion), streaming replication, synchronous quorum, and logical decoding slots for CDC.
- **Declarative Resources**: `Cluster`, `DatabaseRole` (with automated TLS client certs), `Database`, `Backup`, `ScheduledBackup`, and `Pooler` CRDs.
- **Services & Traffic Policies**: Custom service configurations supporting `internalTrafficPolicy: Local` and `externalTrafficPolicy: Local`.
- **Disaster Recovery**: Barman Cloud object stores (S3/GCS/Azure/MinIO), VolumeSnapshots, Point-in-Time Recovery (PITR), and cross-region Replica Clusters.
- **Storage & Performance**: Dedicated WAL storage, online volume expansion, declarative tablespaces, and `cnpg bench` (fio & pgbench).
- **Operations & Day-2**: In-depth `kubectl cnpg` CLI cheatsheet, rolling upgrades, zero-downtime reloads, instance fencing, maintenance mode, and troubleshooting runbooks.

---

### [GitLab CI/CD](./skills/gitlab-ci/SKILL.md)

Expert guide and runbooks for authoring, validating, debugging, and optimizing GitLab CI/CD pipelines (integrated via Git submodule from `https://gitlab.com/gitlab-org/ci-cd/gitlab-ci-skill.git` on branch `main`).

#### Coverage

- Pipeline creation from scratch and incremental job authoring.
- CI/CD Catalog component integration and rules authoring.
- Local pipeline validation and troubleshooting failing jobs.
- DAG execution (`needs:`), parallel matrices, and cache optimization.

---

### [Kubernetes](./skills/kubernetes/SKILL.md)

Production-grade guide and operational runbooks for Kubernetes architecture, workloads, networking, storage, security, and cluster operations synthesized directly from the official Kubernetes documentation.

#### Coverage

- **Control Plane & Nodes**: Architecture loops, etcd quorum, kubelet, and CRI runtimes.
- **Workloads**: Hardened Deployments, StatefulSets with volume templates, DaemonSets, Jobs, CronJobs, and probes.
- **Networking & Gateway API**: ClusterIP, NodePort, LoadBalancer, Ingress, Gateway API HTTPRoutes, and default-deny NetworkPolicies.
- **Storage & CSI**: StorageClasses (WaitForFirstConsumer), PVC expansion, and VolumeSnapshots.
- **Security & RBAC**: Pod Security Standards (Restricted profile), scoped RBAC, and container context hardening.
- **Scheduling & Operations**: Topology Spread Constraints, taints/tolerations, zero-downtime rollouts, and `kubectl debug` troubleshooting.

---

### [Prometheus](./skills/prometheus/SKILL.md)

Exhaustive reference for Prometheus v3.x systems monitoring and alerting toolkit synthesized directly from the official Prometheus documentation.

#### Coverage

- **Server Architecture**: Pull model, target discovery lifecycle, Agent Mode (stateless forwarding), Gorilla compression, and scrape evaluation loops.
- **Data Model & Metric Types**: Counters, Gauges, Classic Histograms, Summaries, and dynamic Native Histograms with exponential bucket layouts.
- **PromQL & Querying**: Selectors, operators, aggregations, 50+ built-in functions, subqueries, offset/@ modifiers, staleness tracking, and type coercion.
- **Configuration**: Complete `prometheus.yml` schema, global settings, scrape configs, 30+ service discovery mechanisms (Kubernetes SD roles, Consul, DNS, EC2, HTTP SD, File SD), and relabeling pipelines (`relabel_configs` and `metric_relabel_configs`).
- **Alerting & Alertmanager**: Alerting rule evaluation (`for`, `keep_firing_for`), Alertmanager architecture, gossip HA mesh, routing trees, multi-channel receivers (Slack, PagerDuty, Email, Webhook, OpsGenie), inhibition rules, scheduled muting (`time_intervals`), and silences.
- **Storage, Federation & Remote Write**: Local TSDB block layout (chunks, index, tombstones), WAL mechanics, compaction, retention (time & size), backfilling, snapshots, hierarchical and cross-service federation, and Remote Write 1.0/2.0 specifications with queue tuning.
- **Instrumentation & Exporters**: Client libraries (Go, Java, Python, Ruby), exposition formats (Prometheus Text 0.0.4/1.0.0, OpenMetrics 1.0.0, Protobuf), content negotiation, Pushgateway mechanics, writing exporters, and multi-target probing patterns.
- **Operations & Security**: Security model, `web-config.yml` (TLS/mTLS and bcrypt basic auth), CLI flags for `prometheus` and `alertmanager`, `promtool` commands (config checking, rule unit tests, TSDB analysis), Management and Admin APIs.
- **Best Practices & Zen**: Metric and label naming conventions (`_total`, `_seconds`, `_bytes`), cardinality control, recording rule naming (`level:metric:operation`), symptom-based alerting, and the 15 Zen principles of Prometheus.

---

### [Grafana](./skills/grafana/SKILL.md)

Comprehensive reference for building, provisioning, and operating Grafana 13.x — dashboards, template variables, file-based provisioning, and unified alerting, synthesized for production observability stacks (Prometheus, Loki, Tempo, SQL, Zabbix).

#### Coverage

- **Dashboards & Panels**: dashboard JSON model (`schemaVersion`, `uid`, `gridPos`), panel types and `fieldConfig` overrides, transformations, query and built-in annotations, library panels, time ranges and NOC-safe refresh.
- **Template Variables**: query/datasource/custom/interval variables, chained filters, `${var:format}` interpolation options, repeat panels and rows, global variables (`$__rate_interval`, `$__range`).
- **Provisioning**: YAML schema for data sources, dashboard providers (`foldersFromFilesStructure`), plugins, and alerting resources; `$__env` / `$__file` secret interpolation; GitOps promotion patterns and drift prevention.
- **Unified Alerting**: Grafana-managed vs datasource-managed rules, expression chains (reduce, threshold, math), `for` / `keep_firing_for` / NoData handling, notification policy tree (group timings, nested branches), contact points (Slack, webhook, email), mute timings, and silences.
- **Data Sources**: UID-based addressing, `secureJsonData`, Prometheus/Loki/Tempo/SQL specifics, community plugins (Zabbix app), health checks and proxy debugging.
- **RBAC & Administration**: org roles, teams, folder permissions, service accounts and tokens, `grafana.ini` essentials, SSO mapping, high-availability deployment, and upgrade hygiene.
- **As Code**: Terraform provider resources (`grafana_folder`, `grafana_dashboard`, `grafana_rule_group`, `grafana_contact_point`, `grafana_notification_policy`, `grafana_service_account`).

---

### [Zabbix](./skills/zabbix/SKILL.md)

Comprehensive reference for operating Zabbix 7.0/8.0 LTS at scale — data collection, trigger logic, template/macro design, escalation-driven alerting, JSON-RPC automation, and distributed proxying, focused on NOC-grade monitoring operations.

#### Coverage

- **Architecture & Components**: server/agent/agent2/proxy/frontend/database roles, server HA (6.0+), internal process families, `zabbix_server.conf` essentials, ports and firewall stance.
- **Items & Data Collection**: item types (passive/active/trapper/SNMP/HTTP/dependent/calculated), key syntax, preprocessing pipelines (JSONPath, JS, discard-unchanged), LLD with filters/overrides, user parameters, `zabbix_sender`.
- **Triggers & Events**: 5.4+ expression syntax (`last`, `avg`, `nodata`, `timeleft`), severities, dependencies, per-trigger vs global correlation, problem lifecycle, acknowledgement, services/SLA trees.
- **Templates & Macros**: inheritance and nesting, official templates, user/secret/context/LLD macros and precedence, tags strategy for routing and services, template design checklist.
- **Actions & Alerting**: conditions/operations, escalation chains, media types, webhook JavaScript (`HttpRequest`, `Zabbix.log`), message templates, discovery and auto-registration guardrails.
- **API**: token auth with Bearer header, `.get` query model, `problem.get` / `event.acknowledge` NOC workflows, `configuration.export/import` as code, automation patterns.
- **Proxies & Scale**: active/passive proxies, hybrid memory buffering (7.0+), proxy groups/HA, NVPS sizing, TimescaleDB + housekeeper, internal health metrics, TLS/PSK, upgrade path.
- **Best Practices**: naming conventions, symptom-based paging, tag routing, maintenance windows, capacity planning, security, upgrade discipline.

---

### [PostgreSQL Tuning](./skills/postgresql-tuning/SKILL.md)

Operational reference for vanilla (non-operator) PostgreSQL 13–17: configuration sizing, query and index analysis, autovacuum and bloat, locking, connection management, WAL/checkpoints, and backup/recovery.

#### Coverage

- **Architecture & Processes**: postmaster/backends, background workers, memory areas, MVCC garbage, WAL and checkpointer, storage layout, replication context.
- **Configuration Tuning**: sizing rules for OLTP/OLAP, memory parameters, WAL and checkpoint tuning, planner costs on NVMe, connection and parallel-query limits, per-table autovacuum.
- **Query Analysis & Indexes**: `EXPLAIN (ANALYZE, BUFFERS)` reading, `pg_stat_statements` workload ranking, index types (B-tree/composite/covering/partial/expression/GIN/BRIN), `CREATE INDEX CONCURRENTLY` discipline.
- **Vacuum & Bloat**: thresholds and per-table overrides, `fillfactor` and HOT updates, bloat measurement (`pgstattuple`), wraparound monitoring, blockers (long transactions, replication slots).
- **Locking & Contention**: lock modes, `pg_blocking_pids` trees, deadlock prevention, hot-row sharding, `SKIP LOCKED` queues, advisory locks, DDL lock safety.
- **Maintenance, Backup & Recovery**: physical + logical layers, WAL archiving, PITR with `recovery_target_action=pause`, restore rehearsal, `pg_upgrade` path.
- **Best Practices**: tuning discipline, monitoring query set, capacity planning inputs, and anti-pattern table.

---

### [Linux Observability](./skills/linux-observability/SKILL.md)

Host-level diagnosis and monitoring design — from PSI pressure to bpftrace, with alert thresholds that survive contact with reality.

#### Coverage

- **Signals & USE**: utilization/saturation/errors per resource, PSI `some`/`full` semantics, metric sources table (`/proc`, cgroup v2, node exporter), sampling and cardinality discipline.
- **CPU & Scheduling**: loadavg vs runnable/D-state split, per-mode accounting (`steal`/`iowait`/`softirq`), cgroup throttling (`cpu.stat`), scheduler latency probes, NUMA.
- **Memory & Pressure**: `MemAvailable` truth, page cache and refaults, `pgscan_direct`, swap-in rate as the signal, OOM scoring, cgroup v2 limits, leak vs workload analysis.
- **Disk & Filesystem**: `await` over `%util`, PSI io, dirty/writeback tuning, filesystem and mount choices, deleted-but-open files, inodes, SMART, RAID/LVM thin pools.
- **Network Stack**: socket states, retransmits vs drops categorization, ring buffers/channels/qdisc, conntrack limits, DNS/NSS latency, BDP and congestion control.
- **Logs, Journald & Tracing**: journald rate-limit traps, structured JSON logs with trace ids, kernel evidence, `perf` sampling, targeted `bpftrace` recipes, tcpdump discipline.
- **Host Alerting & Best Practices**: alert catalogue with `for` windows, node exporter mapping, noise control, capacity inputs, triage order, anti-pattern table.

---

### [QA Automation](./skills/qa-automation/SKILL.md)

Automated quality gates for delivery pipelines: the right test at the right layer, deterministic data, flake control, and CI wiring that actually blocks.

#### Coverage

- **Strategy & Test Pyramid**: cost/confidence table, automate-first priority list, coverage as a map, layer boundaries, test case design, definition of done, suite metrics.
- **API Testing**: per-endpoint assertion matrix (happy/validation/auth/conflict/idempotency/schema), setup-act-assert-cleanup, environment isolation, schema drift detection, anti-patterns.
- **Browser Testing with Playwright**: CI-safe config decisions, selector hierarchy, web-first waiting, network control, fixtures, sharding, trace-driven debugging.
- **Test Data & Fixtures**: isolation levels, factories over static fixtures, deterministic seeds, transactional rollback, idempotent seed SQL, privacy and cleanup rules.
- **Flakiness & Reliability**: failure taxonomy table, detection via failure-without-change, quarantine policy with deadlines, retries discipline, determinism techniques, metrics.
- **CI Wiring & Quality Gates**: pipeline shape, safe caching, mandatory failure artifacts, the five gates worth blocking on, sharding, environment contracts, reporting.
- **Best Practices**: naming, review habits, assertion discipline, deletion policy, ownership, anti-patterns.

---

### [Cilium v1.20](./skills/cilium/SKILL.md)

Comprehensive reference for Cilium v1.20.5 eBPF-based cloud-native networking, security, and observability synthesized from the official Cilium documentation.

#### Coverage

- **Architecture & eBPF Datapath**: `cilium-agent`, `cilium-operator`, `cilium-cni`, `netkit` vs `veth`, identity-based security model, eBPF maps & dynamic sizing, and Linux kernel requirements.
- **Installation, Migration & Upgrades**: OCI Helm chart (`quay.io/cilium/charts/cilium`), node pool taints, live dual-overlay cluster migration, CNI chaining, preflight checks, and v1.20 upgrade notes.
- **Routing, IPAM & Encryption**: Native Direct Routing vs VXLAN/Geneve overlay, IPAM modes, eBPF masquerading & `ip-masq-agent`, Bandwidth Manager (EDT/BBR), WireGuard/IPsec/Ztunnel encryption, L2 Announcements, VTEP, and Node IPAM LB.
- **Kube-Proxy Replacement**: Socket-LB (cgroup v2), Maglev consistent hashing, DSR (`opt`/`geneve`/`ipip`), XDP acceleration, and `CiliumLocalRedirectPolicy`.
- **Network Policy & Security**: L3/L4/L7 HTTP & DNS/FQDN rules, `CiliumCIDRGroup`, `ingressDeny`/`egressDeny`, Host Firewall policies, Standalone DNS Proxy, and Envoy TLS visibility.
- **BGP & Egress Gateway**: BGP Control Plane (`CiliumBGPClusterConfig`, `CiliumBGPPeerConfig`, `CiliumBGPAdvertisement`, `CiliumBGPNodeConfigOverride`), `CiliumLoadBalancerIPPool`, and `CiliumEgressGatewayPolicy`.
- **Service Mesh & Gateway API**: Gateway API v1.6.3 (`CiliumGatewayClassConfig`), GAMMA, Kubernetes Ingress, `CiliumEnvoyConfig`, and L7 proxy load balancing.
- **ClusterMesh & Hubble**: Multi-cluster Global Services, MCS-API (`ServiceExport`/`ServiceImport`), Hubble CLI/UI, Static & Dynamic Exporters, Prometheus/OpenMetrics (`httpV2` exemplars), performance tuning, and `cilium-dbg` runbooks.

---

## Adding More Skills

This repository is designed to host multiple database and engineering skills. When adding new skills (e.g. Vanilla PostgreSQL Tuning, Patroni, pgvector, or connection poolers):

1. Create a dedicated directory: `skills/<skill-name>/`
2. Define a root `SKILL.md` with standard YAML frontmatter (`name` and `description`).
3. Place architectural and runbook deep dives in `references/`.
4. Place sample manifests and configuration templates in `examples/`.

---

## Validation & CI/CD

All skills, links, and manifests are automatically validated on each commit and pull request via GitHub Actions ([validate.yml](./.github/workflows/validate.yml)) using `node scripts/validate.js`:

- **Markdown & Frontmatter**: Ensures all relative markdown links resolve correctly and all `SKILL.md` files possess valid YAML frontmatter (`name` and `description`).
- **Submodule Links**: Submodule-aware verification ensuring cross-repository submodule links resolve cleanly.

To run validation locally before committing:

```bash
node scripts/validate.js
```
