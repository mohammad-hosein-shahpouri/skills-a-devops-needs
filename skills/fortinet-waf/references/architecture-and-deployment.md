# Architecture & Deployment

## Platform Positions in the Traffic Path

FortiWeb runs in front of web/CDN origins. Pick the mode by what the network can
give you, not by feature lists:

| Mode | Traffic flow | Use when |
|------|--------------|----------|
| **Reverse Proxy** | FortiWeb terminates client TCP/TLS, opens new connections to servers | Default choice; full L7 features, SSL offload, caching |
| **True Transparent Proxy** | L7 proxy with original client IP preserved via transparency | Need WAF features + client IP without re-architecting |
| **Inline Bridge (L2)** | Layer-2 bump in the wire, no routing changes | Insertion without touching routing/NAT |
| **One-Arm / Sniffer** | Mirror traffic for detection only | Monitor mode before enforcement, forensics |

Rules of thumb: reverse proxy is the production default; bridge mode is for
minimal-touch insertion; sniffer mode is for the observation period that should
precede any blocking rollout.

## Request Processing Order (matters for tuning)

```text
NIC → DoS prevention (L3/L4) → Virtual Server → Web Protection Profile:
  1. Access control (IP lists, GeoIP, reputation)
  2. DoS prevention (L7)
  3. Signature / anomaly / bot layers (profile-defined order)
  4. Server Policy pass-through → Server Pool (health-checked)
Response path → response inspection (DLP, content filters)
```

Consequence: an IP-blocked client never reaches signatures; a request that fails
DoS never reaches ML. Order your expensive layers after cheap rejections.

## Virtual Servers & Server Policies

- **Virtual Server** — the listening front end (VIP): IP, port, SSL config.
- **Server Policy** — binds virtual server → server pool + web protection
  profile + access settings; the unit you clone per service.
- One FortiWeb can host many virtual servers (per site/per tenant); keep a
  naming convention (`vs-prod-shop-443`).

## Server Pools & Health Checks

- Pool members: real servers with weight, connection limits, admin status.
- **Health checks**: HTTP GET status match, HTTPS with SNI, TCP connect.
  Tune intervals — aggressive checks on flaky origins cause flapping; pair
  with `deletion of host` care.
- **Persistence**: source-IP, cookie-based (`insert`/`pass-through`) — cookie
  persistence is the safe default for app servers.
- Load-balancing methods: round-robin, weighted, least-connection, first-alive;
  `first-alive` is effectively active/passive.

## Routing Modes

| Mode | Notes |
|------|-------|
| NAT (reverse proxy) | FortiWeb owns the public IP; real servers have private IPs — cleanest |
| Transparent | Real servers see client IPs; requires client→VIP routing hygiene |
| Hybrid | Per-virtual-server choice |

Document per-deployment: who owns DNS, where NAT happens, and the return path
(real servers must answer through FortiWeb — default gateway or policy routing).

## VDOM and Multi-Tenancy

- Administrative partitioning; each VDOM has its own virtual servers, policies,
  and (in newer builds) admin domains.
- Use VDOMs for tenant separation when compliance requires it; otherwise naming
  + admin profiles are lighter-weight.

## Capacity Notes

- Proxy-mode throughput depends on SSL: measure with real ciphers/session reuse.
- Connection table and new-connections-per-second are the NOC-relevant limits
  (`get system performance top`, `diagnose system connection`).
- Offloading (HTTP/2 to clients, keep-alive to servers) changes perceived
  latency more than raw throughput tuning — verify with end-to-end timing.
