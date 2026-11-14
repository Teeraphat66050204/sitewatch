#!/usr/bin/env bash
# Project: SiteWatch - Website & Service Monitoring
# Member Name 1: [รายชื่อสมาชิก 1]
# Member Name 2: [รายชื่อสมาชิก 2]
# Member Name 3: [รายชื่อสมาชิก 3]
# Member Name 4: [รายชื่อสมาชิก 4]
# Run: sudo bash install.sh
set -euo pipefail
if (( EUID != 0 )); then
    printf 'ERROR: run with sudo bash install.sh\n' >&2
    exit 1
fi
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
for file in "$ROOT/bin/sitewatch.sh" "$ROOT/bin/sitewatch-monitor.sh" "$ROOT/bin/sitewatch-run.sh" \
    "$ROOT/bin/sitewatch-report.sh" "$ROOT/config/sitewatch.conf" \
    "$ROOT/systemd/sitewatch.service" "$ROOT/systemd/sitewatch.timer"; do
    [[ -f "$file" ]] || { printf 'Missing required file: %s\n' "$file" >&2; exit 1; }
done
for cmd in curl getent nc awk sed flock systemctl; do
    command -v "$cmd" >/dev/null 2>&1 || { printf 'Missing command: %s\n' "$cmd" >&2; exit 1; }
done
install -d -m 0755 /usr/local/lib/sitewatch/bin /etc/sitewatch /var/lib/sitewatch
install -m 0755 "$ROOT/bin/sitewatch.sh" "$ROOT/bin/sitewatch-monitor.sh" "$ROOT/bin/sitewatch-run.sh" \
    "$ROOT/bin/sitewatch-report.sh" /usr/local/lib/sitewatch/bin/
if [[ ! -f /etc/sitewatch/sitewatch.conf ]]; then
    install -m 0644 "$ROOT/config/sitewatch.conf" /etc/sitewatch/sitewatch.conf
else
    printf 'Keeping existing config: /etc/sitewatch/sitewatch.conf\n'
fi
install -m 0644 "$ROOT/systemd/sitewatch.service" "$ROOT/systemd/sitewatch.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now sitewatch.timer
printf 'Installed. Check: systemctl list-timers --all | grep sitewatch\n'
printf 'Run immediately: sudo systemctl start sitewatch.service\n'
