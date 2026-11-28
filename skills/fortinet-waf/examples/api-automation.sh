#!/usr/bin/env bash
# FortiWeb REST API automation — login, status, config backup, policy export.
# Synthetic environment: FORTIWEB_HOST points at your management interface.
# Requires: curl, jq. Token auth (API admin, least privilege, secret manager).

set -euo pipefail

FORTIWEB_HOST="${FORTIWEB_HOST:?export FORTIWEB_HOST=<mgmt-host>}"
FORTIWEB_TOKEN="${FORTIWEB_TOKEN:?export FORTIWEB_TOKEN=<api-token>}"

API="https://${FORTIWEB_HOST}/api/v2.0"
CURL_OPTS=(-sS --connect-timeout 5 --max-time 20
           -H "Authorization: ${FORTIWEB_TOKEN}"
           -H 'Content-Type: application/json')

# ─── 1. System status snapshot (health for NOC) ─────────────────────────────
status() {
    curl "${CURL_OPTS[@]}" "${API}/system/status" | jq '.results[0]'
}

# ─── 2. Full config backup (download as file) ───────────────────────────────
backup_config() {
    local stamp out
    stamp="$(date +%F_%H%M)"
    out="fortiweb-config-${stamp}.conf"
    curl "${CURL_OPTS[@]}" "${API}/system/config?mkey=backup" -o "${out}"
    echo "config saved: ${out}"
    # Verify non-empty and contains a config marker before trusting it
    grep -q "config system global" "${out}" || {
        echo "ERROR: backup content invalid" >&2; rm -f "${out}"; exit 1; }
}

# ─── 3. Export server policies (config-as-data diff) ────────────────────────
export_policies() {
    curl "${CURL_OPTS[@]}" "${API}/cmdb/server-policy/policy" \
        | jq '.results[] | {mkey, name, server_pool, web_protection_profile}'
}

# ─── 4. Server pool member health ───────────────────────────────────────────
pool_health() {
    local pool="${1:?usage: pool_health <pool-name>}"
    curl "${CURL_OPTS[@]}" "${API}/cmdb/system/server-pool?filter=name=${pool}" \
        | jq '.results[0] | {name, members: [.server[] | {ip: .ip, port: .port, status: .status}]}'
}

# ─── 5. Attack log tail (recent N entries, needs log feature enabled) ───────
attack_tail() {
    local n="${1:-20}"
    curl "${CURL_OPTS[@]}" "${API}/log/attack?count=${n}" \
        | jq '.results[] | {time: .timestamp, severity, attack, action,
                            src: .src_ip, url: .url, policy: .policy}'
}

# ─── 6. Create a period-block for one source IP (time-boxed response) ───────
block_source() {
    local ip="${1:?usage: block_source <ip>}"
    case "${ip}" in *[!0-9.]*) echo "ERROR: invalid IP" >&2; exit 2;; esac
    curl "${CURL_OPTS[@]}" -X POST "${API}/cmdb/waf/ip-list-policy" \
        -d "{\"name\":\"incident-${ip}\",\"type\":\"black-list\",\"ip_ranges\":[{\"type\":\"range-ip\",\"start-ip\":\"${ip}\",\"end-ip\":\"${ip}\"}]}" \
        | jq '.results'
    echo "remember: record the block in the incident ticket with an expiry"
}

case "${1:-help}" in
    status)   status ;;
    backup)   backup_config ;;
    policies) export_policies ;;
    pool)     shift; pool_health "$@" ;;
    attacks)  attack_tail "${2:-20}" ;;
    block)    shift; block_source "$@" ;;
    *) cat <<'USAGE'
usage:
  ./api-automation.sh status            # system status snapshot
  ./api-automation.sh backup           # nightly config backup (verify marker)
  ./api-automation.sh policies         # export server policies for diff
  ./api-automation.sh pool <name>      # pool member health
  ./api-automation.sh attacks [N]      # recent attack log tail
  ./api-automation.sh block <ip>       # time-boxed source block (record it!)
USAGE
    ;;
esac

# Notes:
# * Store FORTIWEB_TOKEN in a secret manager; do not commit it.
# * API endpoints vary by FortiWeb release — verify paths against your firmware's
#   REST API reference before scripting.
# * Every block created by automation must have an expiry owner recorded.
# * Nightly backup + the marker check above is the minimum integrity gate.
