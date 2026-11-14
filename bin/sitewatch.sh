#!/usr/bin/env bash
# Project: SiteWatch - Website & Service Monitoring
# Member Name 1: [รายชื่อสมาชิก 1]
# Member Name 2: [รายชื่อสมาชิก 2]
# Member Name 3: [รายชื่อสมาชิก 3]
# Member Name 4: [รายชื่อสมาชิก 4]
set -euo pipefail

readonly SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/sitewatch.conf"
DATA_DIR="/var/lib/sitewatch"
LOG_FILE=""
VERBOSE=0
DRY_RUN=0
REPORT_ONLY=0
LOG_READY=0
TIMEOUT=5
HTTP_MIN=200
HTTP_MAX=399
URLS=()
SERVICES=()

log() {
    local level="$1" message
    shift
    message="$(date '+%F %T%z') [$level] $*"
    printf '%s\n' "$message" >&2
    if (( LOG_READY )); then
        printf '%s\n' "$message" >> "$LOG_FILE"
    fi
}

debug() {
    if (( VERBOSE )); then log INFO "$*"; fi
}

fail() {
    log ERROR "$*"
    exit 1
}

usage() {
    cat <<EOF_HELP
Usage: $SCRIPT_NAME [-c FILE] [-v] [-n] [-r] [-h]
  -c FILE  Select a trusted SiteWatch config file
  -v       Show details for each DNS, TCP and HTTP check
  -n       Dry-run: validate/list targets without checking or writing files
  -r       Print uptime report from previous CSV checks (no new checks)
  -h       Show this help
EOF_HELP
}

check_deps() {
    local cmd
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || fail "Missing dependency: $cmd"
    done
}

trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

valid_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]{1,5}$ ]] || return 1
    (( 10#$port >= 1 && 10#$port <= 65535 ))
}

parse_url() {
    local url="$1" scheme
    if [[ "$url" =~ ^(https?)://([A-Za-z0-9._-]+)(:([0-9]{1,5}))?([/?#].*)?$ ]]; then
        scheme="${BASH_REMATCH[1]}"
        URL_HOST="${BASH_REMATCH[2]}"
        URL_PORT="${BASH_REMATCH[4]:-}"
        if [[ -z "$URL_PORT" ]]; then
            if [[ "$scheme" == https ]]; then URL_PORT=443; else URL_PORT=80; fi
        fi
        valid_port "$URL_PORT"
        return $?
    fi
    return 1
}

parse_service() {
    local service="$1"
    if [[ "$service" =~ ^([A-Za-z0-9._-]+):([0-9]{1,5})$ ]]; then
        SERVICE_HOST="${BASH_REMATCH[1]}"
        SERVICE_PORT="${BASH_REMATCH[2]}"
        valid_port "$SERVICE_PORT"
        return $?
    fi
    return 1
}

load_config() {
    [[ -r "$CONFIG_FILE" ]] || fail "Cannot read config: $CONFIG_FILE"
    # Configuration is trusted Bash syntax, not an untrusted text file.
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"

    [[ "$(declare -p URLS 2>/dev/null || :)" == 'declare -a '* ]] || fail 'URLS must be a Bash array'
    [[ "$(declare -p SERVICES 2>/dev/null || :)" == 'declare -a '* ]] || fail 'SERVICES must be a Bash array'
    [[ "$TIMEOUT" =~ ^[1-9][0-9]*$ ]] || fail 'TIMEOUT must be a positive integer'
    [[ "$HTTP_MIN" =~ ^[0-9]{3}$ && "$HTTP_MAX" =~ ^[0-9]{3}$ ]] || fail 'Invalid HTTP status range'
    (( 10#$HTTP_MIN >= 100 && 10#$HTTP_MAX <= 599 && 10#$HTTP_MIN <= 10#$HTTP_MAX )) || fail 'Invalid HTTP status range'
    (( ${#URLS[@]} + ${#SERVICES[@]} > 0 )) || fail 'No targets configured'

    DATA_DIR="${SITEWATCH_DATA_DIR:-$DATA_DIR}"
    [[ "$DATA_DIR" == /* && "$DATA_DIR" != / ]] || fail 'DATA_DIR must be an absolute directory, not /'
    LOG_FILE="${SITEWATCH_LOG_FILE:-$DATA_DIR/sitewatch.log}"
    [[ "$LOG_FILE" == /* ]] || fail 'LOG_FILE must be an absolute path'

    local target
    for target in "${URLS[@]}"; do
        target="$(trim "$target")"
        parse_url "$target" || fail "Invalid URL: $target"
    done
    for target in "${SERVICES[@]}"; do
        target="$(trim "$target")"
        parse_service "$target" || fail "Invalid service (expected host:port): $target"
    done
}

check_dns() {
    local host="$1"
    DNS_STATUS=FAIL
    if getent ahosts "$host" >/dev/null 2>&1; then DNS_STATUS=OK; fi
}

check_tcp() {
    local host="$1" port="$2"
    TCP_STATUS=CLOSED
    if nc -z -w "$TIMEOUT" "$host" "$port" >/dev/null 2>&1; then TCP_STATUS=OPEN; fi
}

check_http() {
    local url="$1" response=""
    HTTP_CODE=000
    RESPONSE_SEC=0.000
    if response="$(curl -sSL -o /dev/null \
        --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" --max-redirs 5 \
        -w '%{http_code} %{time_total}' -- "$url" 2>/dev/null)"; then
        read -r HTTP_CODE RESPONSE_SEC <<< "${response:-000 0.000}"
    else
        RESPONSE_SEC="${response##* }"
        HTTP_CODE=000
    fi
    [[ "$HTTP_CODE" =~ ^[0-9]{3}$ ]] || HTTP_CODE=000
    [[ "$RESPONSE_SEC" =~ ^[0-9]+([.][0-9]+)?$ ]] || RESPONSE_SEC=0
    RESPONSE_SEC="$(awk -v s="$RESPONSE_SEC" 'BEGIN {printf "%.3f", s+0}')"
}

check_url() {
    local url="$1" status=DOWN
    parse_url "$url" || fail "Invalid URL: $url"
    check_dns "$URL_HOST"
    check_tcp "$URL_HOST" "$URL_PORT"
    check_http "$url"
    if [[ "$DNS_STATUS" == OK && "$TCP_STATUS" == OPEN ]] &&
        (( 10#$HTTP_CODE >= 10#$HTTP_MIN && 10#$HTTP_CODE <= 10#$HTTP_MAX )); then
        status=UP
    fi
    printf 'URL\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$url" "$DNS_STATUS" "$TCP_STATUS" "$HTTP_CODE" "$RESPONSE_SEC" "$status" >> "$RESULT_TMP"
    debug "URL $url DNS=$DNS_STATUS TCP=$TCP_STATUS HTTP=$HTTP_CODE time=${RESPONSE_SEC}s status=$status"
}

check_service() {
    local service="$1" status=DOWN
    parse_service "$service" || fail "Invalid service: $service"
    check_dns "$SERVICE_HOST"
    check_tcp "$SERVICE_HOST" "$SERVICE_PORT"
    if [[ "$DNS_STATUS" == OK && "$TCP_STATUS" == OPEN ]]; then status=UP; fi
    printf 'SERVICE\t%s\t%s\t%s\t-\t-\t%s\n' \
        "$service" "$DNS_STATUS" "$TCP_STATUS" "$status" >> "$RESULT_TMP"
    debug "SERVICE $service DNS=$DNS_STATUS TCP=$TCP_STATUS status=$status"
}

csv_quote() {
    local value="${1//\"/\"\"}"
    printf '"%s"' "$value"
}

save_results() {
    local type target dns tcp http seconds status previous stamp count=0
    local csv_file="$DATA_DIR/results.csv" state_file="$DATA_DIR/state.tsv"
    if [[ ! -e "$csv_file" ]]; then
        printf 'timestamp,type,target,dns,tcp,http_code,response_sec,status\n' > "$csv_file"
    fi

    while IFS=$'\t' read -r type target dns tcp http seconds status; do
        [[ -n "$type" ]] || continue
        [[ "$status" == UP || "$status" == DOWN ]] || fail "Unexpected status: $status"
        stamp="$(date '+%F %T%z')"
        printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
            "$(csv_quote "$stamp")" "$(csv_quote "$type")" \
            "$(csv_quote "$target")" "$(csv_quote "$dns")" \
            "$(csv_quote "$tcp")" "$(csv_quote "$http")" \
            "$(csv_quote "$seconds")" "$(csv_quote "$status")" >> "$csv_file"

        previous=""
        if [[ -r "$state_file" ]]; then
            previous="$(awk -F '\t' -v t="$type" -v n="$target" \
                '$1==t && $2==n {print $3; exit}' "$state_file")"
        fi
        if [[ -n "$previous" && "$previous" != "$status" ]]; then
            if [[ "$status" == DOWN ]]; then
                log WARN "ALERT: $type $target changed $previous -> DOWN"
            else
                log INFO "RECOVERY: $type $target changed $previous -> UP"
            fi
        fi
        printf '%s\t%s\t%s\n' "$type" "$target" "$status" >> "$STATE_TMP"
        count=$((count + 1))
    done < "$RESULT_TMP"
    (( count > 0 )) || fail 'No monitoring results were produced'
    mv -f -- "$STATE_TMP" "$state_file"
    log INFO "Recorded $count checks to $csv_file"
}

calculate_uptime() {
    local csv_file="$DATA_DIR/results.csv"
    [[ -r "$csv_file" ]] || fail "No CSV history at $csv_file"
    awk '
    function field(line, wanted,   i,c,nextc,inside,num,out) {
        inside=0; num=1; out=""
        for (i=1; i<=length(line); i++) {
            c=substr(line,i,1); nextc=substr(line,i+1,1)
            if (c=="\"") {
                if (inside && nextc=="\"") { out=out "\""; i++ }
                else { inside=!inside }
            } else if (c=="," && !inside) {
                if (num==wanted) return out
                num++; out=""
            } else { out=out c }
        }
        if (num==wanted) return out
        return ""
    }
    NR==1 { next }
    {
        type=field($0,2); target=field($0,3); status=field($0,8)
        if (type=="" || target=="" || (status!="UP" && status!="DOWN")) next
        key=type SUBSEP target; name[key]=type " " target
        total[key]++; if (status=="UP") up[key]++
        all++; if (status=="UP") all_up++
    }
    END {
        printf "Target\tUP\tChecks\tUptime(%%)\n"
        for (key in total) printf "%s\t%d\t%d\t%.2f\n",name[key],up[key],total[key],100*up[key]/total[key]
        if (all) printf "OVERALL\t%d\t%d\t%.2f\n",all_up,all,100*all_up/all
    }' "$csv_file"
}

main() {
    local opt target
    while getopts ':c:vnrh' opt; do
        case "$opt" in
            c) CONFIG_FILE="$OPTARG" ;;
            v) VERBOSE=1 ;;
            n) DRY_RUN=1 ;;
            r) REPORT_ONLY=1 ;;
            h) usage; exit 0 ;;
            :) usage >&2; exit 2 ;;
            \?) usage >&2; exit 2 ;;
        esac
    done
    shift "$((OPTIND - 1))"
    (( $# == 0 )) || { usage >&2; exit 2; }
    (( ! (DRY_RUN && REPORT_ONLY) )) || { usage >&2; exit 2; }

    check_deps date sed awk curl getent nc
    load_config

    if (( DRY_RUN )); then
        for target in "${URLS[@]}"; do log INFO "[dry-run] URL $(trim "$target")"; done
        for target in "${SERVICES[@]}"; do log INFO "[dry-run] SERVICE $(trim "$target")"; done
        return 0
    fi
    if (( REPORT_ONLY )); then
        calculate_uptime
        return 0
    fi

    check_deps flock mktemp mv mkdir
    mkdir -p -- "$DATA_DIR"
    LOG_READY=1
    exec 9>"$DATA_DIR/.sitewatch.lock"
    if ! flock -n 9; then
        log WARN 'Another monitoring run is active; skipping overlap'
        return 0
    fi
    RESULT_TMP="$(mktemp "$DATA_DIR/.results.XXXXXX")"
    STATE_TMP="$(mktemp "$DATA_DIR/.state.XXXXXX")"
    trap 'rm -f -- "$RESULT_TMP" "$STATE_TMP"' EXIT

    for target in "${URLS[@]}"; do check_url "$(trim "$target")"; done
    for target in "${SERVICES[@]}"; do check_service "$(trim "$target")"; done
    save_results
    rm -f -- "$RESULT_TMP" "$STATE_TMP"
    trap - EXIT
}

main "$@"
