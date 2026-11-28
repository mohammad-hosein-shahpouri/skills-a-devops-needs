# Logs & Incident Triage

## Log Types and What Each Answers

| Log type | Answers |
|----------|---------|
| **Attack log** | What was blocked/alerted, from whom, against which URL |
| **Traffic log** | Who accessed what (volume, status) — sampling-aware |
| **Event log** | Admin actions, HA events, system health |
| **Health/status log** | Pool member up/down transitions |

Forward everything to a collector: FortiAnalyzer for native analytics, or
syslog/CEF into your SIEM/Loki. Local disk retention is small by design — the
forwarding pipeline is the real retention.

## Attack Log Triage Workflow

1. **Cluster** — group by signature + URL + time window. Ten alerts of one
   signature from one ASN is one event, not ten.
2. **Attribute** — resolve real client IP (forwarded-IP/XFF when behind CDN);
   check reputation/ASN; look for prior history of that source.
3. **Classify**:
   - **Scanner noise** — broad scanning, low value → confirm Deny working, no page.
   - **Targeted probe** — app-specific signatures hit on one URL → possible
     0-day hunt against your app; escalate to app owner with payload.
   - **Successful bypass attempt** — probing continues *past* a blocked rule
     with different encodings → signature gap; consider custom signature or
     ML retrain.
   - **Traffic spike with no signature hits** — DoS/abuse layer or upstream;
     check DoS L7 logs and pool health.
4. **Act**:
   - Confirmed malicious source/ASN: period-block or reputation/GeoIP rule
     (scoped, with expiry noted).
   - App vulnerability probed: ticket to development with payload; WAF virtual
     patch (custom signature) while the code fix ships.
   - False positive: exception per [false-positive worksheet](../examples/false-positive-worksheet.md).
5. **Record** — incident entry with the log IDs, decision, and revert criteria.

## Blocking Decisions

| Situation | Action |
|-----------|--------|
| Confirmed abuse from one source | Period Block (minutes-hours), monitor return |
| Distributed abuse (many IPs, one pattern) | Signature/custom rule Deny, not IP blocks |
| Attack inside an allow-listed range (partner) | Fix the allow-list scope first |
| Under active DoS | DoS L7 threshold tightening + upstream scrubbing coordination |
| Exploit attempt with known CVE | Virtual patch + development ticket |

## Forwarded-IP Behind CDN

- Configure the trusted proxy list (CDN egress ranges) so `X-Forwarded-For`
  parsing only trusts the edge, and blocking applies to the real client IP.
- Otherwise blocks land on CDN edge IPs — a full-service outage triggered by one
  attacker.

## Metrics for NOC Dashboards

| Metric | Threshold idea |
|--------|----------------|
| Blocked attacks/min per policy | Baseline ± trend; spike = campaign |
| Critical Deny on admin URLs | Any → immediate alert |
| Pool members down | Any member down > 1 min |
| Signature DB age | > 7 days |
| HA sync state | != synchronized |
| Certificate expiry | < 30 days |
| Latency p95 through WAF | Above app SLO budget |

## Anti-Patterns

- Reading attack logs only when users complain — by then it is an outage.
- Blocking by country as a first reflex; it is coarse and full of collateral.
- Deleting "noisy" alerts instead of scoping exceptions.
- Triage without the payload: decisions need `raw data`, not just signature name.
- No forwarding pipeline: logs die with the device.
