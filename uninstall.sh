#!/usr/bin/env bash
# Project: SiteWatch - Website & Service Monitoring
# Member Name 1: [รายชื่อสมาชิก 1]
# Member Name 2: [รายชื่อสมาชิก 2]
# Member Name 3: [รายชื่อสมาชิก 3]
# Member Name 4: [รายชื่อสมาชิก 4]
# Run: sudo bash uninstall.sh [--purge]
set -euo pipefail
if (( EUID != 0 )); then
    printf 'ERROR: run with sudo bash uninstall.sh\n' >&2
    exit 1
fi
PURGE=1
if (( $# > 1 )); then
    printf 'Usage: sudo bash uninstall.sh [--keep-data]\n' >&2
    exit 2
fi
if (( $# == 1 )); then
    if [[ "$1" == "--keep-data" ]]; then PURGE=0
    elif [[ "$1" == "--purge" ]]; then PURGE=1
    else printf 'Usage: sudo bash uninstall.sh [--purge]\n' >&2; exit 2
    fi
fi
systemctl disable --now sitewatch.timer 2>/dev/null || true
systemctl stop sitewatch.service 2>/dev/null || true
rm -f /etc/systemd/system/sitewatch.service /etc/systemd/system/sitewatch.timer
systemctl daemon-reload
systemctl reset-failed sitewatch.service 2>/dev/null || true
rm -rf -- /usr/local/lib/sitewatch
rm -f /etc/sitewatch/sitewatch.conf
rmdir /etc/sitewatch 2>/dev/null || true
if (( PURGE )); then
    rm -rf -- /var/lib/sitewatch
    printf 'Uninstalled, including stored CSV and state.\n'
else
    printf 'Uninstalled. CSV and state preserved in /var/lib/sitewatch.\n'
    printf 'Use --keep-data to preserve records instead.\n'
fi
