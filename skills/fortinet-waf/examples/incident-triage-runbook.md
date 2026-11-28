# WAF Incident Triage Runbook

Trigger: attack-log spike, pool member flapping, latency through WAF, or a NOC
page on critical denies. Goal: classify within five minutes, act, and record.

## 0) Inputs to Pull First

- Attack logs for the window (signature, severity, action, src, URL, raw data)
- Traffic log trend (requests/min before vs during)
- Pool health + member states
- Recent changes (config drift diff, signature DB update time)
- Where is the client IP real? (CDN XFF configured?)

## 1) Classify the Spike

| Pattern | Classification | Go to |
|---------|----------------|-------|
| One signature, many IPs, broad URLs | Scanner campaign | 2A |
| App-specific signatures on one URL, repeated encodings | Targeted probe | 2B |
| Critical Deny on admin URLs | High-value attack attempt | 2C |
| Huge request volume, few/no signature hits | DoS / abuse | 2D |
| Deny spike right after signature update / config change | Self-inflicted FP | 2E |

## 2A) Scanner Campaign

- Confirm Deny actions are working (blocked count grows, latency normal).
- Optional: period-block the top abusive ASN/ranges (time-boxed, note expiry).
- No page needed; add to weekly report unless volume affects service.

## 2B) Targeted Probe

- Extract payloads (`raw data`); look for encoding escalation — that means the
  attacker is iterating past the current rule.
- Open a P2 ticket to the app owner with payloads attached.
- Consider a **custom signature** scoped to the URL + parameter as a virtual
  patch while the code path is reviewed.
- Page if the URL is auth/payment-adjacent.

## 2C) Admin-Surface Attack

- Verify admin allow-list held (source should be allow-list ranges only; if not,
  the access list is broken — fix immediately).
- Check `log admin` for any successful admin session from unexpected sources.
- Treat as security incident: preserve logs, notify security owner, rotate admin
  credentials if any session succeeded.

## 2D) DoS / Abuse Layer

- Check DoS L7 logs: which URL class, which action level is engaging.
- Tighten per-URL thresholds (documented change), enable captcha tier if
  business accepts it for the affected class.
- If origin saturation is real (pool members timing out), coordinate upstream
  scrubbing/CDN challenge; WAF alone cannot save a saturated origin.

## 2E) Self-Inflicted False-Positive Wave

- Identify the rule (signature ID or ML URL) that started firing.
- Roll back action one level (Deny → Alert) — a scoped, documented change.
- Run the false-positive worksheet; re-enable after benign replay passes.

## 3) Post-Incident Record

```text
window:        start–end (UTC)
classification: scanner / targeted / admin / dos / false-positive
volumes:       attacks/min, requests/min, denies
actions taken:  (rule changes, blocks, tickets)
verification:  synthetic path green, benign replay pass, metrics back to baseline
revert dates:  any time-boxed blocks
```

## 4) Follow-Ups

- Ticket to development for any targeted-probe payload (code review the URL).
- Weekly report entry: campaigns, top attacked URLs, FP exceptions delta.
- If bypass suspected (probing continues past Deny), open a signature-gap item:
  custom signature candidate + ML retrain consideration.
