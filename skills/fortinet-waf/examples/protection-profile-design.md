# Protection Profile Design Notes

Layered profile for a production e-commerce class service (`wpp-prod-shop`).
Order follows the cheap-to-expensive principle; each layer has a documented
action and rollback.

## Layer Design

| # | Layer | Config | Action | Rollback |
|---|-------|--------|--------|----------|
| 1 | IP Reputation | FortiGuard feed | Deny | Disable feed per policy |
| 2 | GeoIP | Deny-list (documented hostile regions) | Deny | Remove deny-list entry |
| 3 | Access list | Allow monitors/partners | Bypass | Remove entry |
| 4 | DoS L3/L4 | SYN flood protections | Reset | Lower thresholds to alert |
| 5 | DoS L7 | Request limits per URL class (login/search/checkout) | Limit→Block | Raise thresholds |
| 6 | Bot mitigation | Verified crawlers allow; captcha on suspect UA | Challenge | Remove challenge rule |
| 7 | ML anomaly | Per-URL models; Alert then Block per threshold | Alert→Deny | Raise threshold / retrain |
| 8 | Signatures | Critical+High Deny; Medium Alert; Low Alert | Deny/Alert | Per-rule action change |
| 9 | Protocol validation | HTTP constraints (URL/header lengths) | Deny | Relax constraint |
| 10 | Response checks | Info disclosure (server tokens, stack traces) | Alert→Sanitize | Alert only |

## URL Class Strategy

| URL class | Extra strictness |
|-----------|------------------|
| `/admin*` | Source allow-list only; signatures at max severity set |
| `/api/*` | JSON validation; HTML-form rules off; rate limits keyed by token not IP |
| `/login`, `/checkout` | Aggressive L7 rate limit + bot challenge |
| static assets | Signature-light (no SQLi class needed on images) |

## Change Record Template (per profile change)

```text
date:        2026-11-28
policy:      wpp-prod-shop
layer/rule:  signature #<id> action Alert -> Deny (scope: /checkout, param: card)
reason:      FP rate 0/7 days; attack trend from <campaign>
verified:    synthetic replay of benign checkout passed
revert:      set action back to Alert
owner:       <team>
```

## Rollout Sequence (new service onboarding)

1. Attach profile in **Alert-only** mode (or a monitor-mode deployment).
2. Collect one week of attack logs; classify FP vs true positive.
3. Apply scoped exceptions for confirmed FPs (worksheet entries).
4. Flip Critical/High to Deny; hold Medium at Alert one more week.
5. Enable bot challenge and L7 limits for login/checkout classes.
6. Enable ML: train → review → threshold enforcement.
7. Review profile monthly; archive the change records with it.

## Metrics That Validate the Profile

- Deny-to-Alert ratio per severity (enforcement maturity)
- False-positive exceptions opened/closed per month (tuning health)
- Synthetic benign replay pass rate after each change
- Attacks blocked on admin surface (should be zero if allow-list holds)
