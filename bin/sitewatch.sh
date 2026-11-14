#!/usr/bin/env bash
# SiteWatch integration fallback (CSV, state, change-only alerts)
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MONITOR="$SCRIPT_DIR/sitewatch-monitor.sh"
CONFIG_FILE="$SCRIPT_DIR/../config/sitewatch.conf"
if [[ -r /etc/sitewatch/sitewatch.conf && ! -r "$CONFIG_FILE" ]]; then
    CONFIG_FILE=/etc/sitewatch/sitewatch.conf
fi
DATA_DIR="${SITEWATCH_DATA_DIR:-}"
VERBOSE=0
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: sitewatch.sh [-c CONFIG] [-v] [-n] [-h]
  -c FILE  Monitoring configuration
  -v       Print verbose monitoring details to stderr
  -n       Dry run; validate only, do not write CSV or state
  -h       Help
Env: SITEWATCH_DATA_DIR overrides /var/lib/sitewatch for local tests.
EOF
}
log() {
    local level="$1"
    shift
    printf '%s [%s] %s\n' "$(date '+%F %T%z')" "$level" "$*" >&2
}
csv_quote() {
    local value="${1//\"/\"\"}"
    printf '"%s"' "$value"
}
main() {
    local option tmp state_tmp type target dns tcp http seconds status prev now row_count=0
    while getopts ':c:vnh' option; do
        case "$option" in
            c) CONFIG_FILE="$OPTARG" ;;
            v) VERBOSE=1 ;;
            n) DRY_RUN=1 ;;
            h) usage; exit 0 ;;
            :) usage >&2; exit 2 ;;
            \?) usage >&2; exit 2 ;;
        esac
    done
    shift "$((OPTIND - 1))"
    if (( $# != 0 )); then usage >&2; exit 2; fi
    [[ -r "$MONITOR" ]] || { log ERROR "Missing monitoring script: $MONITOR"; exit 1; }

    [[ -r "$CONFIG_FILE" ]] || { log ERROR "Config not readable: $CONFIG_FILE"; exit 1; }
    # Only source trusted project configuration files.
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    DATA_DIR="${SITEWATCH_DATA_DIR:-${DATA_DIR:-/var/lib/sitewatch}}"
    [[ -n "$DATA_DIR" && "$DATA_DIR" == /* && "$DATA_DIR" != / ]] || { log ERROR 'DATA_DIR must be an absolute directory (not /)'; exit 1; }

    local args=(-c "$CONFIG_FILE")
    if (( VERBOSE )); then args+=(-v); fi
    if (( DRY_RUN )); then
        exec bash "$MONITOR" "${args[@]}" -n
    fi

    for option in flock mktemp awk date; do
        command -v "$option" >/dev/null 2>&1 || { log ERROR "Missing dependency $option"; exit 1; }
    done
    mkdir -p "$DATA_DIR"
    exec 9>"$DATA_DIR/.sitewatch.lock"
    if ! flock -n 9; then
        log WARN "A monitoring run is already active; skipping overlapping run"
        return 0
    fi

    tmp="$(mktemp "$DATA_DIR/.results.XXXXXX")"
    state_tmp="$(mktemp "$DATA_DIR/.state.XXXXXX")"
    trap 'rm -f -- "$tmp" "$state_tmp"' EXIT

    if bash "$MONITOR" "${args[@]}" >"$tmp"; then
        :
    else
        local rc=$?
        log ERROR "Monitor failed with exit code $rc"
        exit "$rc"
    fi

    local csv_file="$DATA_DIR/results.csv" state_file="$DATA_DIR/state.tsv"
    if [[ ! -e "$csv_file" ]]; then
        printf 'timestamp,type,target,dns,tcp,http_code,response_sec,status\n' >"$csv_file"
    fi

    while IFS=
        [[ -n "$type" ]] || continue
        if [[ "$status" != UP && "$status" != DOWN ]]; then
            log ERROR "Invalid monitor result: $status"
            exit 1
        fi
        now="$(date '+%F %T%z')"
        printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
            "$(csv_quote "$now")" "$(csv_quote "$type")" \
            "$(csv_quote "$target")" "$(csv_quote "$dns")" \
            "$(csv_quote "$tcp")" "$(csv_quote "$http")" \
            "$(csv_quote "$seconds")" "$(csv_quote "$status")" >>"$csv_file"

        prev=""
        if [[ -r "$state_file" ]]; then
            prev="$(awk -F '\t' -v t="$type" -v n="$target" '$1==t && $2==n {print $3; exit}' "$state_file")"
        fi
        if [[ -n "$prev" && "$prev" != "$status" ]]; then
            if [[ "$status" == DOWN ]]; then
                log WARN "ALERT: $type $target changed $prev -> DOWN"
            else
                log INFO "RECOVERY: $type $target changed $prev -> UP"
            fi
        fi
        printf '%s\t%s\t%s\n' "$type" "$target" "$status" >>"$state_tmp"
        row_count=$((row_count + 1))
    done <"$tmp"
    if (( row_count == 0 )); then
        log ERROR "Monitor produced no records"
        exit 1
    fi
    mv -f -- "$state_tmp" "$state_file"
    rm -f -- "$tmp"
    trap - EXIT
    log INFO "Recorded $row_count checks to $csv_file"
}
main "$@"
\t' read -r type target dns tcp http seconds status; do
        [[ -n "$type" ]] || continue
        if [[ "$status" != UP && "$status" != DOWN ]]; then
            log ERROR "Invalid monitor result: $status"
            exit 1
        fi
        now="$(date '+%F %T%z')"
        printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
            "$(csv_quote "$now")" "$(csv_quote "$type")" \
            "$(csv_quote "$target")" "$(csv_quote "$dns")" \
            "$(csv_quote "$tcp")" "$(csv_quote "$http")" \
            "$(csv_quote "$seconds")" "$(csv_quote "$status")" >>"$csv_file"

        prev=""
        if [[ -r "$state_file" ]]; then
            prev="$(awk -F '\t' -v t="$type" -v n="$target" '$1==t && $2==n {print $3; exit}' "$state_file")"
        fi
        if [[ -n "$prev" && "$prev" != "$status" ]]; then
            if [[ "$status" == DOWN ]]; then
                log WARN "ALERT: $type $target changed $prev -> DOWN"
            else
                log INFO "RECOVERY: $type $target changed $prev -> UP"
            fi
        fi
        printf '%s\t%s\t%s\n' "$type" "$target" "$status" >>"$state_tmp"
        row_count=$((row_count + 1))
    done <"$tmp"
    if (( row_count == 0 )); then
        log ERROR "Monitor produced no records"
        exit 1
    fi
    mv -f -- "$state_tmp" "$state_file"
    rm -f -- "$tmp"
    trap - EXIT
    log INFO "Recorded $row_count checks to $csv_file"
}
main "$@"
