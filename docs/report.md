# SiteWatch — Website and Service Monitoring
**Course:** LINUX and OPERATIONS (1/69) — Linux Automation Project  
**Project:** Topic 4, SiteWatch  
**Date prepared:** 14 November 2026  
**Group members:** [Add real member names and IDs before submission]

## 1. Objectives
Implement a practical Bash automation utility to monitor web URLs and TCP host:port services, record repeated checks, calculate observed uptime, and notify operators only when a monitored target changes state. The tool is meant to run automatically every 3 minutes with a systemd timer.

## 2. System concept
1. Read the external trusted Bash configuration defining URL arrays, service arrays, timeout and success-code range.
2. Validate inputs and confirm necessary commands exist.
3. Check DNS using `getent ahosts`, TCP using `nc -z -w`, and HTTP status/response time using `curl`.
4. Determine UP or DOWN for each target. A URL must pass DNS, TCP, and configured HTTP status checks; a service must pass DNS and TCP.
5. Append a timestamped record for each target to CSV. Load previous state per target and issue alerts only for UP -> DOWN and DOWN -> UP.
6. Atomically update the state file, calculate uptime percentage from CSV, and let systemd repeat the run every 3 minutes.

## 3. Components
- `bin/sitewatch.sh`: main Bash entrypoint, option handling, CSV/state/transition alerts, logging, coordination.
- `bin/sitewatch-monitor.sh`: technical network checks and tab-separated result stream.
- `bin/sitewatch-report.sh`: uptime report from CSV history.
- `config/sitewatch.conf`: monitored targets, timeout, HTTP status limits, data directory.
- `systemd/sitewatch.service`: Type=oneshot invocation of the main script.
- `systemd/sitewatch.timer`: first check after boot and every 3 minutes after a completed check.
- `install.sh`, `uninstall.sh`: repeatable installation and clean removal.

## 4. Commands and algorithm
`curl` collects the final HTTP code and `time_total` (seconds), with connection and overall timeouts. `getent` tests name resolution, and `nc` checks whether the TCP port is reachable. `awk` performs numeric processing/reporting, while `sed` trims user-supplied target whitespace. All major scripts use a shebang and `set -euo pipefail`; the main script includes `main()` and additional functions.

## 5. Uptime and files
The CSV contains `timestamp,type,target,dns,tcp,http_code,response_sec,status`. The state file stores `type,target,last_status` as TSV. Uptime percentage is `100 * number_of_UP_checks / number_of_all_checks` for each target. This is **sampled uptime**, not continuous time-based availability. All state is keyed by both type and target.

## 6. Configuration and CLI
`-h` shows help; `-c FILE` selects a configuration; `-v` displays detailed diagnostic logs; `-n` validates configuration and lists targets without performing network checks or writing data. Exit codes are: 0 successful operation, 1 configuration/runtime error, and 2 invalid usage. Logs have timestamps and INFO/WARN/ERROR severities; systemd records them in the journal.

## 7. Scheduling, installation and uninstall
`sudo bash install.sh` installs scripts under `/usr/local/lib/sitewatch/bin`, installs a config to `/etc/sitewatch/sitewatch.conf`, creates `/var/lib/sitewatch`, deploys the oneshot service and timer, then enables the timer. Re-running install retains any existing installed config. `sudo bash uninstall.sh --purge` disables the timer, removes installed files and deletes stored CSV/state. The monotonic timer uses `OnBootSec=1min` and `OnUnitInactiveSec=3min`; `Persistent=true` is only appropriate for supported calendar timers, so it is not used here.

## 8. Validation and demonstration
Test cases to capture:
1. Help (`-h`) and dry-run (`-n`).
2. A running local Python HTTP server at `127.0.0.1:8000` reports HTTP 200 and UP.
3. Stopping it results in HTTP 000, closed TCP, DOWN and a single alert.
4. Checking again while down creates no duplicate alert.
5. Restarting the web server produces DOWN -> UP recovery log.
6. A non-resolving `.invalid` domain reports DNS FAIL and DOWN.
7. Missing config gives ERROR/exit 1; invalid option gives exit 2.
8. A ShellCheck pass, timer listing, journal logs, CSV/uptime report.
9. Fresh VM install and complete uninstall.

**Verification status:** Monitoring UP/DOWN and ShellCheck were manually demonstrated on the group's Ubuntu 26.04 VM; GitHub Actions validates automated branch tests. The course PDF requires Ubuntu Server 22.04/24.04 or Rocky Linux 9, so the final demonstration should be repeated on a compliant VM. No claim is made that the entire system has already been tested on the group's VM.

## 9. Limitations and next steps
The parser handles HTTP/HTTPS URLs with IPv4 or hostnames, but not bracketed IPv6 hosts. Authentication-protected websites may require different HTTP success criteria. Local demo targets can be changed in the config. The generated PDF is a report **draft**: add all real student information and the team's captured screenshots in `docs/screenshots/` before submitting.

## 10. Presentation checklist
- Install on a clean supported Ubuntu/Rocky VM.
- Show `systemctl list-timers` and `journalctl -u sitewatch.service` with timestamps.
- Run `sitewatch.sh -h`, `-v`, and `-n` by hand.
- Simulate a stopped web server and a missing configuration.
- Show CSV output, sampled uptime, latest state, and transition alerts.
- Run `uninstall.sh --purge` and confirm removal.
