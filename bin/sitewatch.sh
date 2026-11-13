#!/usr/bin/env bash
# SiteWatch - Website & Network Monitoring (member 1)
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/sitewatch.conf"
VERBOSE=0
DRY_RUN=0
TIMEOUT=5
HTTP_MIN=200
HTTP_MAX=399

usage() {
    cat <<'EOF'
Usage: sitewatch.sh [-c CONFIG] [-v] [-n] [-h]
  -c FILE  Load a different configuration file
  -v       Show detailed checks on stderr
  -n       Dry-run: validate and list targets without network checks
  -h       Show this help

Output (stdout): one tab-separated line per target, no header
TYPE<TAB>TARGET<TAB>DNS<TAB>TCP<TAB>HTTP_CODE<TAB>RESPONSE_SEC<TAB>STATUS
Status UP/DOWN describes the monitored target, not script execution.
EOF
}

log() {
    local level="$1"
    shift
    printf '%s [%s] %s\n' "$(date '+%F %T')" "$level" "$*" >&2
}

debug() {
    if (( VERBOSE == 1 )); then
        log INFO "$*"
    fi
}

fail() {
    log ERROR "$*"
    exit 1
}

require_commands() {
    local command_name
    for command_name in curl getent nc awk sed date; do
        command -v "$command_name" >/dev/null 2>&1 || fail "Missing command: $command_name"
    done
}

trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

valid_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]{1,5}$ ]] && (( 10#$port >= 1 && 10#$port <= 65535 ))
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
        valid_port "$URL_PORT" || return 1
        return 0
    fi
    return 1
}

parse_service() {
    local service="$1"
    if [[ "$service" =~ ^([A-Za-z0-9._-]+):([0-9]{1,5})$ ]]; then
        SERVICE_HOST="${BASH_REMATCH[1]}"
        SERVICE_PORT="${BASH_REMATCH[2]}"
        valid_port "$SERVICE_PORT" || return 1
        return 0
    fi
    return 1
}

load_config() {
    [[ -r "$CONFIG_FILE" ]] || fail "Cannot read config: $CONFIG_FILE"
    # Configuration files are shell code. Only use trusted project config files.
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"

    [[ "$(declare -p URLS 2>/dev/null || :)" == 'declare -a '* ]] || fail 'URLS must be a Bash array'
    [[ "$(declare -p SERVICES 2>/dev/null || :)" == 'declare -a '* ]] || fail 'SERVICES must be a Bash array'
    [[ "$TIMEOUT" =~ ^[1-9][0-9]*$ ]] || fail 'TIMEOUT must be a positive integer in seconds'
    [[ "$HTTP_MIN" =~ ^[0-9]{3}$ && "$HTTP_MAX" =~ ^[0-9]{3}$ ]] || fail 'HTTP_MIN and HTTP_MAX must be 3-digit numbers'
    (( 10#$HTTP_MIN >= 100 && 10#$HTTP_MIN <= 599 && 10#$HTTP_MAX >= 100 && 10#$HTTP_MAX <= 599 && 10#$HTTP_MIN <= 10#$HTTP_MAX )) || fail 'Invalid HTTP status range'
    (( ${#URLS[@]} + ${#SERVICES[@]} > 0 )) || fail 'The config has no targets'

    local target
    for target in "${URLS[@]}"; do
        target="$(trim "$target")"
        parse_url "$target" || fail "Invalid URL: $target (use http/https, hostname/IPv4, optional port)"
    done
    for target in "${SERVICES[@]}"; do
        target="$(trim "$target")"
        parse_service "$target" || fail "Invalid service: $target (expected hostname:port)"
    done
}

check_dns() {
    local host="$1"
    if getent ahosts "$host" >/dev/null 2>&1; then
        printf 'OK'
    else
        printf 'FAIL'
    fi
}

check_tcp() {
    local host="$1" port="$2"
    if nc -z -w "$TIMEOUT" "$host" "$port" >/dev/null 2>&1; then
        printf 'OPEN'
    else
        printf 'CLOSED'
    fi
}

check_http() {
    local url="$1" result
    HTTP_CODE=000
    RESPONSE_SEC=0.000
    if result="$(curl -sSL -o /dev/null \
        --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
        --max-redirs 5 -w '%{http_code} %{time_total}' \
        -- "$url" 2>/dev/null)"; then
        :
    fi
    read -r HTTP_CODE RESPONSE_SEC <<< "${result:-000 0.000}"
    [[ "$HTTP_CODE" =~ ^[0-9]{3}$ ]] || HTTP_CODE=000
    [[ "$RESPONSE_SEC" =~ ^[0-9]+([.][0-9]+)?$ ]] || RESPONSE_SEC=0
    RESPONSE_SEC="$(awk -v seconds="$RESPONSE_SEC" 'BEGIN { printf "%.3f", seconds + 0 }')"
}

monitor_url() {
    local url="$1" dns tcp status
    parse_url "$url" || fail "Invalid URL: $url"
    dns="$(check_dns "$URL_HOST")"
    tcp="$(check_tcp "$URL_HOST" "$URL_PORT")"
    check_http "$url"
    status=DOWN
    if [[ "$dns" == OK && "$tcp" == OPEN ]] && \
       (( 10#$HTTP_CODE >= 10#$HTTP_MIN && 10#$HTTP_CODE <= 10#$HTTP_MAX )); then
        status=UP
    fi
    printf 'URL\t%s\t%s\t%s\t%s\t%s\t%s\n' "$url" "$dns" "$tcp" "$HTTP_CODE" "$RESPONSE_SEC" "$status"
    debug "URL $url: DNS=$dns TCP=$tcp HTTP=$HTTP_CODE time=${RESPONSE_SEC}s status=$status"
}

monitor_service() {
    local service="$1" dns tcp status
    parse_service "$service" || fail "Invalid service: $service"
    dns="$(check_dns "$SERVICE_HOST")"
    tcp="$(check_tcp "$SERVICE_HOST" "$SERVICE_PORT")"
    status=DOWN
    if [[ "$dns" == OK && "$tcp" == OPEN ]]; then
        status=UP
    fi
    printf 'SERVICE\t%s\t%s\t%s\t-\t-\t%s\n' "$service" "$dns" "$tcp" "$status"
    debug "SERVICE $service: DNS=$dns TCP=$tcp status=$status"
}

main() {
    local option target
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
    (( $# == 0 )) || { usage >&2; exit 2; }

    require_commands
    load_config
    if (( DRY_RUN == 1 )); then
        for target in "${URLS[@]}"; do log INFO "[dry-run] URL $(trim "$target")"; done
        for target in "${SERVICES[@]}"; do log INFO "[dry-run] SERVICE $(trim "$target")"; done
        exit 0
    fi

    for target in "${URLS[@]}"; do monitor_url "$(trim "$target")"; done
    for target in "${SERVICES[@]}"; do monitor_service "$(trim "$target")"; done
}

main "$@"
