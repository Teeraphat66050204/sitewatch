#!/usr/bin/env bash
# Run: sudo bash uninstall.sh [--purge]
set -euo pipefail
if (( EUID != 0 )); then
    printf 'ERROR: run with sudo bash uninstall.sh\n' >&2
    exit 1
fi
PURGE=0
if (( $# > 1 )); then
    printf 'Usage: sudo bash uninstall.sh [--purge]\n' >&2
    exit 2
fi
if (( $# == 1 )); then
    if [[ "$1" == "--purge" ]]; then PURGE=1
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
    printf 'Uninstalled, including stored CSV and state (--purge).\n'
else
    printf 'Uninstalled. CSV and state preserved in /var/lib/sitewatch.\n'
    printf 'Use --purge to remove saved records too.\n'
fi
