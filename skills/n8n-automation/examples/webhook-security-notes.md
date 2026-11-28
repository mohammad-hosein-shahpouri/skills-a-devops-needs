# Webhook Security Notes

Hardening checklist for n8n webhook intake in NOC pipelines.

## Authentication Layers (pick per sender capability)

| Layer | Mechanism | Notes |
|-------|-----------|-------|
| **Header auth** (n8n credential) | Shared secret header on every request | Baseline; works with every sender |
| **HMAC signature** | Sender signs body; n8n verifies in a Code node | Best when the sender supports it |
| **mTLS** | Client certs at the reverse proxy | Strongest; proxy-level setup |
| **IP allow-list** | Reverse proxy restricts to sender egress IPs | Defense in depth — combine, never rely on alone |

Baseline production combo: header auth (n8n) + reverse-proxy IP allow-list +
TLS. Signature verification when the sender can sign.

## Verification Patterns

Header auth failure: n8n returns 401 automatically; the sender must treat it as
retryable only after fixing config — alert on repeated 401s (they mean
misconfiguration or probing).

HMAC sketch (Code node after Webhook):

```javascript
const crypto = require('crypto');
const secret = $credentials.sharedSecret;      // via credential, not hardcoded
const body = JSON.stringify($json.body);       // exact bytes the sender signed
const sig = crypto.createHmac('sha256', secret).update(body).digest('hex');
if (sig !== $json.headers['x-signature']) {
  throw new Error('invalid signature');
}
return items;
```

Payload-byte caution: verify against the exact raw bytes (n8n exposes raw body
on the webhook node); re-serializing JSON can break byte equality.

## Reverse Proxy Layer

- `client_max_body_size` limited (e.g. 1MB) — oversized payload defense.
- Rate limit per source (e.g. 100 rps) — flood defense before n8n.
- Only production paths exposed: `/webhook/*` public to senders;
  `/webhook-test/*` never exposed (editor-only).
- TLS termination with modern policy; HSTS on the domain.

## Payload Validation (after auth)

- Schema-check required fields (`source`, `alert_id`, `severity`) — reject 400
  early with a clear message; malformed payloads are a sender bug worth a ticket.
- Cap field lengths; strip unexpected giant fields before persisting execution
  data.

## Editor and API Exposure

- Editor (`/`, `/signin`) behind SSO/OIDC or at minimum strong auth + IP
  restriction to NOC/jump ranges.
- REST API (`/api/v1`) — token-per-integration, least privilege, rotated.
- Never expose the editor and the intake on the same trust level: two instances
  (internal ops vs public intake) is the clean pattern.

## Monitoring the Surface

| Signal | Meaning |
|--------|---------|
| 401 rate rising | Sender misconfig or probing |
| 4xx from validation | Sender schema drift |
| Payload size p95 growth | Sender adding fields unannounced |
| New webhook paths appearing | Config drift — audit quarterly |

## Checklist (per production webhook)

- [ ] Auth layer configured and tested (401 verified)
- [ ] IP allow-list at proxy (documented sender ranges)
- [ ] Payload schema documented next to the workflow
- [ ] Fast response (2xx) before heavy work
- [ ] Size limits set at proxy
- [ ] 401/4xx rates monitored
- [ ] Owner named in workflow description
