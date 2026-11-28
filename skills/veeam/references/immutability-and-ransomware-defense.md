# Immutability & Ransomware Defense

## The Threat Model

Modern ransomware targets **backups first**: it hunts for the backup server
credentials, deletes jobs, wipes repositories, then detonates on production.
Defense = make at least one copy unchangeable and unreachable by the compromised
production identity.

## 3-2-1-1-0 Rule

| Digit | Meaning |
|-------|---------|
| 3 | Three copies of data |
| 2 | Two different media/platforms |
| 1 | One copy offsite |
| **1** | **One copy immutable/offline** |
| **0** | **Zero errors on verification** |

Audit quarterly: any missing digit is a remediation ticket with an owner.

## Hardened Linux Repository

- XFS with reflinks for fast synthetic fulls; single-use credentials (sudo
  elevation only for Veeam service); immutability window per backup files.
- Deployment checklist: dedicated host, minimal OS, no other services, SSH
  key-only admin, firewall to proxy networks only.
- **Immutability period**: files cannot be deleted before the window expires —
  set to exceed your retention + incident response time (e.g. 14-30 days).
- Note: immutability protects the data, not the host — patch the OS.

## Object Storage Immutability

- S3 Object Lock (compliance mode) on the capacity/archive tier; same window
  logic as hardened repos.
- Bucket credentials for the backup server should lack delete permission during
  the lock window — design so deletion is impossible, not just forbidden.

## Encryption

- Backup file encryption (AES-256) with a **password escrow policy** — the
  password cannot be recovered from the backup server; losing it loses the
  backups.
- Encrypt the configuration backup too; escrow that password as well.
- Transport to object storage over TLS.

## Credential Hygiene (how ransomware actually gets in)

1. The backup server stores credentials for hypervisors and repos — assume a
   compromised production domain can reach it. Mitigate:
   - Backup server NOT domain-joined (workgroup) with local accounts.
   - Separate account per layer: hypervisor read, repo write, guest processing.
2. MFA for the backup server console / Enterprise Manager logins.
3. Restrict console access by network (jump host only).
4. Alerts on job deletion and repository credential changes — those are
   intrusion indicators.

## Detection & Response Aids

| Signal | Meaning |
|--------|---------|
| Job deletion/modification outside change windows | Possible intrusion |
| Repository usage drop (points deleted) | Someone is pruning history |
| Backup copy lag growing | Secondary copy falling behind during attack |
| Integrity check failures | Tampering or storage fault — treat as hostile first |

## Practice Checklist

1. Primary backup + immutable second copy + offsite/archive: all three exist.
2. Immutability window exceeds incident-response time.
3. Configuration backup enabled, encrypted, password escrowed.
4. Quarterly restore verification with **0 errors** is the last digit.
5. Tabletop the scenario "production domain is compromised" once a year and walk
   how you reach backups.
