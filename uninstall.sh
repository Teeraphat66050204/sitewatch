#!/usr/bin/env bash
# Project: SiteWatch - Website & Service Monitoring
# Member Name 1: [รายชื่อสมาชิก 1]
# Member Name 2: [รายชื่อสมาชิก 2]
# Member Name 3: [รายชื่อสมาชิก 3]
# Member Name 4: [รายชื่อสมาชิก 4]
set -euo pipefail

if (( EUID != 0 )); then
    printf 'ERROR: use sudo bash uninstall.sh\n' >&2
    exit 1
fi
KEEP_DATA=0
if (( $# > 1 )); then
    printf 'Usage: sudo bash uninstall.sh [--keep-data]\n' >&2
    exit 2
fi
if (( $# == 1 )); then
    if [[ "$1" == --keep-data ]]; then KEEP_DATA=1
    else printf 'Usage: sudo bash uninstall.sh [--keep-data]\n' >&2; exit 2
    fi
fi
systemctl disable --now sitewatch.timer 2>/dev/null || true
systemctl stop sitewatch.service 2>/dev/null || true
rm -f /etc/systemd/system/sitewatch.service /etc/systemd/system/sitewatch.timer
systemctl daemon-reload
systemctl reset-failed sitewatch.service 2>/dev/null || true
rm -f /usr/local/lib/sitewatch/bin/sitewatch.sh
rmdir /usr/local/lib/sitewatch/bin /usr/local/lib/sitewatch 2>/dev/null || true
rm -f /etc/sitewatch/sitewatch.conf
rmdir /etc/sitewatch 2>/dev/null || true
if (( ! KEEP_DATA )); then
    rm -rf -- /var/lib/sitewatch
    printf 'SiteWatch uninstalled, including its recorded data.\n'
else
    printf 'SiteWatch uninstalled. Data retained under /var/lib/sitewatch.\n'
fi
