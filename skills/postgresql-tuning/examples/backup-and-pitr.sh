#!/usr/bin/env bash
# Physical backup + WAL archiving + point-in-time restore rehearsal
# Schedule base backups externally (cron/systemd timer); this script documents
# the full flow with verification steps.

set -euo pipefail

# ─── Configuration (replace with your environment; keep secrets out of Git) ───
PRIMARY_HOST="${PRIMARY_HOST:-db-primary.example.internal}"
BACKUP_ROLE="${BACKUP_ROLE:-backup_ro}"
BASE_DIR="${BASE_DIR:-/var/backups/postgresql}"
WAL_ARCHIVE_DIR="${WAL_ARCHIVE_DIR:-/var/lib/postgresql/archive}"
PGDATA="${PGDATA:-/var/lib/postgresql/17/main}"

# ─── Input validation (values end up inside shell commands Postgres executes
#     and inside postgresql.conf, so restrict them to safe path/host chars) ───
safe_path() {
    case "$1" in
        /*[!A-Za-z0-9._/-]*) return 1 ;;
        /*) return 0 ;;
        *) return 1 ;;
    esac
}
safe_host() {
    case "$1" in
        *[!A-Za-z0-9._-]*) return 1 ;;
        *) return 0 ;;
    esac
}
for v in BASE_DIR WAL_ARCHIVE_DIR PGDATA; do
    safe_path "${!v}" || { echo "ERROR: $v must be a simple absolute path" >&2; exit 2; }
done
safe_host "${PRIMARY_HOST}" || { echo "ERROR: PRIMARY_HOST contains invalid characters" >&2; exit 2; }

# ─── 1. Weekly full base backup (tar, gzip, progress) ────────────────────────
do_base_backup() {
    local stamp
    stamp="$(date +%F_%H%M)"
    mkdir -p "${BASE_DIR}/base/${stamp}"
    PGPASSWORD="${BACKUP_PASSWORD:?set BACKUP_PASSWORD}" \
    pg_basebackup \
        -h "${PRIMARY_HOST}" -U "${BACKUP_ROLE}" \
        -D "${BASE_DIR}/base/${stamp}" \
        -Ft -z -P --checkpoint=fast
    echo "base backup written to ${BASE_DIR}/base/${stamp}"
}

# ─── 2. WAL archive health check (run hourly) ────────────────────────────────
check_archive() {
    psql -h "${PRIMARY_HOST}" -U "${BACKUP_ROLE}" -d postgres -Atc \
      "SELECT last_archived_wal, last_archived_time, failed_count FROM pg_stat_archiver;"
    local count
    count="$(find "${WAL_ARCHIVE_DIR}" -name '*.gz' -o -name '*.partial' 2>/dev/null | wc -l)"
    echo "segments in archive dir: ${count}"
    # Alert condition: failed_count > 0 or archive older than 30 minutes
}

# ─── 3. PITR rehearsal: restore base backup to a scratch instance ────────────
pitr_restore() {
    local target_time="${1:?usage: pitr_restore '2026-11-28 10:30:00+00'}"
    # target_time is written into postgresql.conf — reject quotes/newlines
    case "${target_time}" in
        *[\'\"\$\\\;\`]*|*$'\n'*) echo "ERROR: invalid recovery target time" >&2; exit 2 ;;
    esac
    local latest
    latest="$(ls -1d "${BASE_DIR}"/base/* | tail -1)"
    local scratch="${BASE_DIR}/restore-test"

    rm -rf "${scratch}"
    mkdir -p "${scratch}"
    tar -xzf "${latest}/base.tar.gz" -C "${scratch}"

    cat >> "${scratch}/postgresql.conf" <<EOF
restore_command = 'cp ${WAL_ARCHIVE_DIR}/%f %p'
recovery_target_time = '${target_time}'
recovery_target_action = 'pause'
EOF
    touch "${scratch}/recovery.signal"

    # Start the scratch instance on a different port for inspection
    pg_ctl -D "${scratch}" -o "-p 5499 -c listen_addresses=''" start
    echo "scratch instance running on 5499; inspect then promote:"
    echo "  psql -p 5499 -d postgres -c 'SELECT pg_promote();'"
    echo "  pg_ctl -D ${scratch} -o '-p 5499' stop"
}

# ─── 4. Logical dump for portability / accidental-delete recovery ───────────
do_logical_dump() {
    local stamp
    stamp="$(date +%F)"
    PGPASSWORD="${BACKUP_PASSWORD:?}" \
    pg_dump -Fc -Z9 -h "${PRIMARY_HOST}" -U "${BACKUP_ROLE}" -d appdb \
        -f "${BASE_DIR}/logical/appdb-${stamp}.dump"
    PGPASSWORD="${BACKUP_PASSWORD:?}" \
    pg_dumpall --globals-only -h "${PRIMARY_HOST}" -U "${BACKUP_ROLE}" \
        -f "${BASE_DIR}/logical/globals-${stamp}.sql"
}

# ─── 5. Verify a dump restores cleanly (monthly) ────────────────────────────
verify_logical_restore() {
    local dump
    dump="$(ls -1 "${BASE_DIR}"/logical/appdb-*.dump | tail -1)"
    psql -d postgres -c "DROP DATABASE IF EXISTS appdb_restore_test;"
    psql -d postgres -c "CREATE DATABASE appdb_restore_test;"
    pg_restore --no-owner --no-privileges -d appdb_restore_test "${dump}"
    psql -d appdb_restore_test -c "SELECT count(*) FROM information_schema.tables
                                   WHERE table_schema = 'public';"
    psql -d postgres -c "DROP DATABASE appdb_restore_test;"
    echo "logical restore verified: ${dump}"
}

case "${1:-help}" in
    base)      do_base_backup ;;
    archive)   check_archive ;;
    pitr)      shift; pitr_restore "$@" ;;
    logical)   do_logical_dump ;;
    verify)    verify_logical_restore ;;
    *) cat <<'USAGE'
usage:
  ./backup-and-pitr.sh base      # full physical base backup
  ./backup-and-pitr.sh archive   # WAL archive health check
  ./backup-and-pitr.sh pitr '2026-11-28 10:30:00+00'   # restore rehearsal
  ./backup-and-pitr.sh logical   # logical dump + globals
  ./backup-and-pitr.sh verify    # restore the latest dump into scratch DB
USAGE
    ;;
esac

# ─── Notes ─────────────────────────────────────────────────────────────────
# * Never store backups on the same volume as PGDATA or pg_wal.
# * failed_count > 0 in pg_stat_archiver means PITR is already degraded.
# * recovery_target_action = 'pause' lets you validate before promoting.
# * Rehearse PITR monthly; an untested backup is not a backup.
