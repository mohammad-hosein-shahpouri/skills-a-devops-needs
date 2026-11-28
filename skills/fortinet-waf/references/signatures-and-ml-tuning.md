# Signatures & ML Tuning

## Reading the Attack Log (the core diagnostic)

Attack log fields you triage from:

| Field | Use |
|-------|-----|
| `attack` | Signature name or ML trigger |
| `severity` | Critical/High/Medium/Low/Info |
| `action` | Alert / Deny / Reset / Period Block / Alert & Deny |
| `src_ip`, `country` | Source attribution (behind CDN: use forwarded-IP logic) |
| `http_host`, `url`, `method` | Which app surface |
| `req_summary` / `raw data` | The offending payload |
| `profile` / `policy` | Which virtual server + protection profile |
| `validation` | Rule ID inside the policy |

**Behind a CDN or LB**, `src_ip` is the edge IP — enable the forwarded-client-IP
feature (XFF handling) or blocking hits everyone on that edge.

## The False-Positive Workflow

1. **Confirm it is a false positive** — legitimate business request matched a
   rule. Ask the app owner with the raw payload attached.
2. **Pick the narrowest exception**, in order of preference:
   - Signature exception scoped to URL + parameter (best)
   - Disable rule for one policy (acceptable short-term)
   - Add source IP allow-list (only for trusted internal scanners)
3. **Never** disable a whole signature category globally to fix one URL.
4. Record every exception in the worksheet with owner, date, and reason
   (see [false-positive-worksheet.md](../examples/false-positive-worksheet.md)).
5. Re-check after each signature update — updates can change rule IDs and
   matching behavior.

## Signature Strategy by Environment

| Phase | Signature action | Goal |
|-------|------------------|------|
| Observation (week 1-2) | Alert only | Learn baseline noise |
| Enforcement (week 3+) | Deny Critical/High, Alert Medium | Block with low FP |
| Mature | Deny Critical/High/Medium per app | Keep Low as detection |

Severity mapping drives paging: Deny-ed Critical attacks on admin surfaces are
incidents; Alert-only Low chatter is a weekly-report item.

## ML Tuning Lifecycle

1. **Train** on representative traffic (2-7 days; include seasonal peaks if the
   parameter shapes differ).
2. **Review learned parameters** per URL: types, lengths, char sets. Fix obvious
   mistakes (a parameter that is JSON learned as string).
3. **Set thresholds**: detection first (Alert), enforcement after a week of clean
   alerts.
4. **Recalculate** after every app release that adds/changes parameters, and
   after big traffic-pattern shifts (campaign, new market).
5. ML false positives typically surface as blocked normal users on one URL —
   confirm via attack log ML trigger, adjust threshold or retrain.

## Custom Signatures

- For app-specific exploits the vendor cannot know: custom regex rules with
  method + URL scope + parameter anchoring.
- Anchor liberally (`&sV=` style parameter binding) — unanchored regex on
  generic patterns is how false-positive storms start.
- Test custom rules in Alert against replayed benign traffic before Deny.

## Metrics to Track

| Metric | Signal |
|--------|--------|
| Attacks by severity per day | Trend and campaign detection |
| Deny vs Alert ratio | Enforcement maturity |
| Top attacked URLs | Where the app is probed |
| Top source countries/ASNs (post-CDN) | Real origin distribution |
| FP exceptions count per month | Tuning health; growing count = review profile design |

## Anti-Patterns

- Tuning from the log of one noisy day instead of a week.
- Global rule disable because an internal scanner trips it — scope to scanner IPs.
- ML enforcement switched on without a training window.
- Exceptions without an owner/reason — six months later nobody knows why the
  rule is off.
- Treating every Alert as noise: alerts are your early warning before the
  attacker finds the bypass.
