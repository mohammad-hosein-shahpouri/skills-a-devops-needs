# False-Positive Worksheet

One row per exception, filled at the moment the exception is made. Exceptions
without a row are invisible debt.

## Worksheet Entry

```text
id:            FP-2026-0042
date:          2026-11-28
opened_by:     <operator>
policy:        wpp-prod-shop
virtual server: vs-prod-shop-443
signature/rule: <signature name or rule id>        (ML: url + parameter)
url:           /api/v1/checkout
method:        POST
parameter:     meta
sample payload: <sanitized raw data excerpt>
legitimate why: <business reason — e.g. structured JSON payload field>
impact if blocked: <what users see>
exception chosen:  [ ] signature exception (url+param scope)
                   [ ] rule action change (Deny -> Alert)
                   [ ] ML threshold adjust / retrain
                   [ ] source allow-list (internal scanner only)
scope:         <exact scope — never global>
revert plan:   re-check after signature DB update on <next update date>
review date:   <30-60 days>
status:        active
```

## Decision Rules

1. **Narrowest wins.** Signature exception on url+parameter beats policy-level
   disable beats category disable. Never category-level.
2. **Alert, then Deny.** When in doubt, change action to Alert first and watch a
   week of logs — data decides enforcement.
3. **Internal scanners get source allow-lists**, not rule changes.
4. **Every exception has an expiry review date.** Signature updates change
   matching; last quarter's exception may be obsolete or dangerous.
5. **Same rule three times = profile design problem.** Stop adding exceptions;
   redesign that layer for the service class.

## Quick Reference — Where Exceptions Live

| Exception type | Config location | Blast radius |
|----------------|-----------------|--------------|
| Signature exception (URL+param) | Web protection profile → signature policy → exceptions | One URL/parameter — preferred |
| Rule action change | Signature policy rule config | All URLs on the profile — needs justification |
| ML threshold | ML policy per URL | One URL — paired with retrain |
| Source allow-list | Access control list | One source — scanner/partner only |
| Constraint relaxation | HTTP protocol constraints | One constraint — check length/type limits |

## Monthly Review

- Count active exceptions; close ones whose reason no longer holds.
- For each active exception: does a recent signature update change its need?
- Trend: a growing exception count on one profile means the profile (or the
  app) needs redesign, not more exceptions.
