# SiteWatch – Monitoring module (member 1)

This module checks HTTP, DNS and TCP. CSV/uptime/state/alerts and timers are implemented by other members.

## Requirements and run

```bash
sudo apt update
sudo apt install -y curl netcat-openbsd shellcheck git
bash bin/sitewatch.sh -h
bash bin/sitewatch.sh -n -c config/sitewatch.conf
bash bin/sitewatch.sh -v -c config/sitewatch.conf
bash -n bin/sitewatch.sh
shellcheck bin/sitewatch.sh
```

The config is a **trusted Bash file** loaded with `source`. Never load untrusted configurations.

## Output contract

One TSV row per target on stdout, with seven columns and no header:

`TYPE<TAB>TARGET<TAB>DNS<TAB>TCP<TAB>HTTP_CODE<TAB>RESPONSE_SEC<TAB>STATUS`

- TYPE: URL or SERVICE
- TARGET: URL or hostname:port
- DNS: OK or FAIL (a literal IP also resolves through getent)
- TCP: OPEN or CLOSED
- HTTP_CODE: final HTTP status (000 on connection failure), or - for SERVICE
- RESPONSE_SEC: request time in seconds, or - for SERVICE
- STATUS: UP or DOWN

URL is UP when DNS is OK, TCP is OPEN, and final HTTP status lies within HTTP_MIN..HTTP_MAX (200..399 by default). SERVICE is UP when DNS is OK and TCP is OPEN. All diagnostics and `-v` output go to stderr; records go only to stdout.

Exit codes: 0=monitor execution completed (even when sites are DOWN), 1=script/config/dependency failure, 2=invalid arguments. `-n` validates and lists targets without performing checks or emitting TSV records.

## Test local UP and DOWN

Terminal 1:
```bash
python3 -m http.server 8000 --bind 127.0.0.1
```

Terminal 2:
```bash
bash bin/sitewatch.sh -v -c config/sitewatch.conf
```

Stop server with Ctrl+C; rerun monitoring to observe DOWN. Start server again to observe UP.

## Integration

Teammate implementing CSV/state can read TSV output with:

```bash
while IFS=$'\t' read -r type target dns tcp http seconds status; do
  printf '%s -> %s\n' "$target" "$status"
done < <(bash bin/sitewatch.sh -c config/sitewatch.conf)
```

Limitations: no bracketed IPv6 support; status range can be customized, but authentication may be needed for protected sites; no alerting or CSV is done in this module.
