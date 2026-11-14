#!/usr/bin/env bash
# Integration smoke test: no sudo, no systemd, no permanent files.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
PORT=18765
SERVER_PID=""

cleanup() {
    if [[ -n "$SERVER_PID" ]]; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT

for command_name in python3 curl nc awk; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'ERROR: missing %s\n' "$command_name" >&2
        exit 1
    }
done

cat > "$TMP_DIR/sitewatch.conf" <<EOF
URLS=("http://127.0.0.1:$PORT")
SERVICES=("127.0.0.1:$PORT")
TIMEOUT=2
HTTP_MIN=200
HTTP_MAX=399
DATA_DIR="$TMP_DIR/data"
EOF

python3 -m http.server "$PORT" --bind 127.0.0.1 >"$TMP_DIR/http.log" 2>&1 &
SERVER_PID=$!
ready=0
for ((i=0; i<20; i++)); do
    if nc -z -w 1 127.0.0.1 "$PORT" 2>/dev/null; then
        ready=1
        break
    fi
    sleep 0.2
done
if (( ready == 0 )); then
    printf 'ERROR: local test server never started\n' >&2
    exit 1
fi

bash "$ROOT/bin/sitewatch.sh" -n -c "$TMP_DIR/sitewatch.conf" >"$TMP_DIR/dry-run.txt" 2>&1
test ! -e "$TMP_DIR/data/results.csv"
bash "$ROOT/bin/sitewatch.sh" -v -c "$TMP_DIR/sitewatch.conf" 2>"$TMP_DIR/up.log"
grep -q '"UP"' "$TMP_DIR/data/results.csv"

kill "$SERVER_PID"
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""
bash "$ROOT/bin/sitewatch.sh" -c "$TMP_DIR/sitewatch.conf" 2>"$TMP_DIR/down.log"
test "$(grep -c 'ALERT:' "$TMP_DIR/down.log")" -eq 2
bash "$ROOT/bin/sitewatch.sh" -c "$TMP_DIR/sitewatch.conf" 2>"$TMP_DIR/still-down.log"
if grep -q 'ALERT:' "$TMP_DIR/still-down.log"; then
    printf 'ERROR: duplicate DOWN alert\n' >&2
    exit 1
fi

python3 -m http.server "$PORT" --bind 127.0.0.1 >"$TMP_DIR/http2.log" 2>&1 &
SERVER_PID=$!
ready=0
for ((i=0; i<20; i++)); do
    if nc -z -w 1 127.0.0.1 "$PORT" 2>/dev/null; then
        ready=1
        break
    fi
    sleep 0.2
done
(( ready == 1 )) || { printf 'ERROR: HTTP restart failed\n' >&2; exit 1; }
bash "$ROOT/bin/sitewatch.sh" -c "$TMP_DIR/sitewatch.conf" 2>"$TMP_DIR/recovery.log"
test "$(grep -c 'RECOVERY:' "$TMP_DIR/recovery.log")" -eq 2

test "$(wc -l < "$TMP_DIR/data/results.csv")" -eq 9
test "$(wc -l < "$TMP_DIR/data/state.tsv")" -eq 2
bash "$ROOT/bin/sitewatch-report.sh" "$TMP_DIR/data/results.csv" \
    | grep -Eq '^OVERALL[[:space:]]+4[[:space:]]+8[[:space:]]+50[.]00$'

set +e
bash "$ROOT/bin/sitewatch.sh" -c "$TMP_DIR/missing.conf" >/dev/null 2>&1
missing_rc=$?
bash "$ROOT/bin/sitewatch.sh" -z >/dev/null 2>&1
invalid_rc=$?
set -e
(( missing_rc == 1 && invalid_rc == 2 )) || {
    printf 'ERROR: exit codes were %d and %d (expected 1, 2)\n' "$missing_rc" "$invalid_rc" >&2
    exit 1
}

printf 'PASS: config/dry-run, UP/DOWN/recovery, no duplicate alerts, CSV/state, uptime 50%%, exit codes.\n'
