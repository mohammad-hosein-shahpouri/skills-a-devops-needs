# Agent Skills Repository Guidelines

This repository is a modular collection of specialized skills designed for AI agents (such as Antigravity, Claude Code, Cursor, and other agent frameworks).

## Repository Architecture

Skills are organized under the `skills/` directory. Each skill follows standard progressive disclosure conventions:

```text
skills/<skill-name>/
├── SKILL.md            # Required: Skill entrypoint with YAML frontmatter
├── references/         # In-depth architectural, configuration, and troubleshooting guides
└── examples/           # Production-ready manifests, code snippets, or templates
```

## Available Skills

- **[ansible](./skills/ansible/SKILL.md)**: Ansible IT automation and configuration management — agentless architecture, `ansible.cfg`, INI/YAML inventories, 22-level variable precedence, roles with `argument_specs.yml`, collections and FQCN, Ansible Vault, Execution Environments (EE), Windows WinRM/PSRP/SSH, and performance tuning (pipelining, forks, async/poll).
- **[cilium](./skills/cilium/SKILL.md)**: Cilium v1.20 eBPF cloud-native networking, security, and observability — native/overlay routing, IPAM, full Kube-Proxy replacement (Socket-LB, Maglev, DSR, XDP), L3/L4/L7/FQDN CiliumNetworkPolicy, BGP Control Plane, Egress Gateway, Gateway API & Service Mesh, ClusterMesh, Hubble, and `cilium-dbg` operations.
- **[cloudnative-pg](./skills/cloudnative-pg/SKILL.md)**: CloudNativePG (PostgreSQL operator for Kubernetes) v1.30 architecture, declarative roles, HA clustering, Barman Cloud backups, PITR, PgBouncer pooling, and operational CLI runbooks.
- **[gitlab-ci](./skills/gitlab-ci/SKILL.md)**: GitLab CI/CD authoring, debugging, validation, and pipeline optimization (added via Git submodule tracking `main`).
- **[kubernetes](./skills/kubernetes/SKILL.md)**: Production-grade Kubernetes architecture, workload controllers (Deployments, StatefulSets), Gateway API, zero-trust NetworkPolicies, storage/CSI, PSS security, and troubleshooting runbooks.
- **[prometheus](./skills/prometheus/SKILL.md)**: Prometheus v3.x monitoring and alerting toolkit — pull-based time-series collection, PromQL query language, multi-dimensional data model, Alertmanager notification pipeline, TSDB storage internals, service discovery, federation, remote write/read, client instrumentation, exposition formats, and operational best practices.
- **[grafana](./skills/grafana/SKILL.md)**: Grafana 13.x observability platform — dashboard authoring and the dashboard JSON model, template variables, provisioning as code (data sources, dashboards, alerting), unified alerting (Grafana-managed and datasource-managed rules), notification policies and contact points, data source configuration, RBAC and administration, and as-code workflows (Terraform).
- **[zabbix](./skills/zabbix/SKILL.md)**: Zabbix 7.0/8.0 LTS enterprise monitoring — server/proxy/agent architecture, item types and preprocessing, trigger expressions, templates and macro inheritance, actions with escalation chains and webhook media types, JSON-RPC API automation, proxy scaling and server HA, and operational best practices.
- **[fortinet-waf](./skills/fortinet-waf/SKILL.md)**: FortiWeb 7.x WAF operations — deployment modes, web protection profile stack (signature, ML anomaly, bot mitigation, DoS), SSL and certificates, HA and hardening, attack-log triage, false-positive tuning, and CLI/REST automation.
- **[veeam](./skills/veeam/SKILL.md)**: Veeam Backup & Replication v12 — architecture (proxies, repositories, SOBR), job design and GFS retention, immutability and ransomware defense (3-2-1-1-0), restore workflows, SureBackup verification, monitoring integration, and PowerShell automation.
- **[n8n-automation](./skills/n8n-automation/SKILL.md)**: n8n workflow automation — regular vs queue mode execution, webhook NOC integrations with deduplication and idempotency, expressions, credentials security, error workflows and dead-letter design, and version-control/deployment practices.

## Contributing / Adding New Skills

When adding future skills (including additional PostgreSQL skills):

1. Create a dedicated directory under `skills/<skill-name>/`.
2. Include a valid `SKILL.md` with YAML frontmatter containing `name` and `description`.
3. Separate conceptual deep-dives into `references/` and manifests/snippets into `examples/`.
4. Validate that all relative markdown links resolve correctly.
