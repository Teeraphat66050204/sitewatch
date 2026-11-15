#!/usr/bin/env bash
# Project: SiteWatch - Website & Service Monitoring
# Member Name 1: 66050204 ธีรภัทร ผลเจริญ
# Member Name 2: 66050033 กิตติคุณ จรูมเคลือ 
# Member Name 3: 66050398 ศรุต สูงสุมาลย์
set -euo pipefail

# Check permission
if (( EUID != 0 )); then
    printf 'ERROR: use sudo bash install.sh\n' >&2
    exit 1
fi

# Find absolute path
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# check if file exist
for file in "$ROOT/bin/sitewatch.sh" "$ROOT/config/sitewatch.conf" \
    "$ROOT/systemd/sitewatch.service" "$ROOT/systemd/sitewatch.timer"; do
    [[ -r "$file" ]] || { printf 'ERROR: missing %s\n' "$file" >&2; exit 1; }
done

# check dependency
for cmd in curl getent nc awk sed flock systemctl; do
    command -v "$cmd" >/dev/null 2>&1 || { printf 'ERROR: missing dependency %s\n' "$cmd" >&2; exit 1; }
done
install -d -m 0755 /usr/local/lib/sitewatch/bin /etc/sitewatch /var/lib/sitewatch
install -m 0755 "$ROOT/bin/sitewatch.sh" /usr/local/lib/sitewatch/bin/sitewatch.sh

if [[ ! -f /etc/sitewatch/sitewatch.conf ]]; then
    install -m 0644 "$ROOT/config/sitewatch.conf" /etc/sitewatch/sitewatch.conf
else
    printf 'Existing configuration preserved: /etc/sitewatch/sitewatch.conf\n'
fi

install -m 0644 "$ROOT/systemd/sitewatch.service" "$ROOT/systemd/sitewatch.timer" /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now sitewatch.timer
printf 'Installed SiteWatch. Run: sudo systemctl start sitewatch.service\n'
