# Web Protection Profiles

A **Web Protection Profile** is the ordered stack of protections a server policy
applies. Design it as layers: cheap deterministic checks first, expensive
adaptive checks last.

## Stack Order (recommended)

1. **Access Control** — allow/deny by source IP, GeoIP, IP reputation
2. **DoS Prevention (L3/L4)** — SYN flood, port scan
3. **DoS Prevention (L7)** — request-per-second per URL/policy
4. **Bot Mitigation** — verified search engines, captcha/challenge for suspect UA
5. **ML/Anomaly Detection** — per-URL learning with thresholds
6. **Signature Policy** — attack signatures by severity and category
7. **Protocol/Data checks** — HTTP protocol validation, constraints (URL, header
   length), custom policy rules
8. **Response-side** — information disclosure, DLP patterns

## Signature Policy

- Select by **category and severity** (Critical/High first; Medium after tuning).
- Actions: Alert, Alert & Deny, Deny (block), Reset, Period Block (source IP
  quarantine for N seconds).
- Start **Alert** (or Alert & Deny on non-critical paths) during rollout; move
  to Deny per-rule after measuring false-positive rate.
- Custom signature rules: regex-based, tied to your app's exploit patterns;
  anchor patterns (`^`, `&sV=`) to avoid over-matching.

## ML Anomaly Detection (the per-URL brain)

- ML builds per-URL models of parameters: type, length, character distribution.
- Flow: put the site in **training** (traffic-only) for enough representative
  traffic → review model → switch threshold levels to enforcement.
- Alert/block thresholds: two knobs; start Alert high (few alerts), then tighten.
- Recalculate the model after major app releases — new parameters cause
  false positives until retrained.
- ML complements signatures; it is strongest on parameter abuse, weakest on
  novel logic flaws.

## Bot Mitigation

- Allow-list verified crawlers (search engines) — do not SEO-block yourself.
- Challenge (captcha) suspect UAs instead of hard-block where business allows.
- Rate-limits per client and per URL class (login, search, checkout) — these
  belong to DoS L7 with clear action levels.
- Track bot traffic share before/after; a jump means an integration broke
  (payment webhooks, partner APIs).

## DoS Prevention (L7)

- Per-policy request limits with progressive actions (alert → limit → block).
- Anomaly-based thresholds learn per URL; keep manual floors for launch/campaign
  spikes so marketing events do not look like attacks.
- Deny duration and period-block are the triage levers: short blocks during
  investigation, longer period-blocks for confirmed abuse.

## Access Control Layers

- **IP lists** — internal networks, monitoring probes (so synthetic checks are
  never blocked), partner ranges.
- **GeoIP** — country allow/deny; usually deny-list obvious hostile regions
  rather than allow-list, unless the business is regional by contract.
- **IP reputation** — FortiGuard-fed; block lists update themselves; monitor
  for false positives from shared cloud egress IPs.

## Profile Hygiene

1. One profile per service class (shop, API, admin panel) — not one giant.
2. Admin panels: strict allow-list + MFA in front; highest-value target.
3. API endpoints: disable HTML-form checks, enable JSON validation constraints.
4. Every change: which policy, which rule, expected effect, and how to revert.
5. Review attack log distribution weekly — the profile is a living config.
