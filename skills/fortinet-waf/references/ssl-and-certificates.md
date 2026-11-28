# SSL & Certificates

## Termination Model

Reverse-proxy mode terminates client TLS on FortiWeb and opens a new session to
the server pool:

- **Client side**: certificate presented here; cipher/TLS policy configurable.
- **Server side**: re-encrypt (HTTPS pool) or offload (HTTP pool) — re-encrypt
  when the path to origins crosses untrusted networks or compliance demands it.
- WAF inspection works natively in both cases because FortiWeb owns the session.

## Certificates

| Source | Use |
|--------|-----|
| Local import (PFX/PEM) | Wildcard/multi-SAN from your CA |
| Let's Encrypt (ACME built-in) | Automated issue/renew per FQDN; needs port 80 route or DNS validation |
| CSR generated on device | Keep private key on-device; store CSR requests |

Operational notes:

- SAN list must cover every hostname on the virtual server; SNI lets one
  virtual server serve multiple certificates.
- Track expiry in monitoring (cert notAfter from the edge) — FortiWeb does not
  page you at 30 days.
- Private key handling: import via admin session only; never email PFX.

## TLS Policy

- Minimum TLS version: 1.2 for anything public; 1.3 where clients allow.
- Cipher policy: use a modern grouped policy rather than hand-listing ciphers;
  verify with an external SSL grader after changes.
- HSTS: enable after confirming all subdomains are HTTPS-capable — HSTS on a
  half-HTTPS estate locks users out.

## SNI and Multi-Tenant Fronting

- Virtual server + SNI certificate selection handles multiple hostnames per IP.
- Keep host→certificate mapping in the config repo; mismatched SNI certs are a
  recurring incident after migrations.

## Behind-CDN Pattern

When a CDN sits in front of FortiWeb:

1. CDN→origin is TLS (re-encrypt) — do not ship HTTP across the internet.
2. Client cert pinning or mTLS between CDN and FortiWeb stops origin bypass
   scanning (direct-to-IP attacks). Alternative: firewall the origin to CDN
   egress ranges only, and verify the origin never resolves publicly.
3. Host header/SNI from CDN must match the certificate the WAF expects — a
   mismatch becomes a silent full-block.

## Health Checks over TLS

- HTTPS health checks must validate the certificate (or explicitly skip) —
  expiry flips all pool members dead simultaneously. Monitor certificate expiry
  independently of health checks.

## Common Pitfalls

1. Renewing the CDN cert but forgetting the origin/edge cert on FortiWeb.
2. Enabling HSTS with a still-mixed-content app.
3. Blocking TLS 1.0/1.1 before old embedded clients are inventoried.
4. Trusting `src_ip` blindly behind CDN without XFF/forwarded-IP handling.
5. No monitoring on certificate expiry because "Let's Encrypt renews itself" —
   automation fails quietly (DNS/validation), and you find out from browsers.
