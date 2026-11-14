# SiteWatch — Website & Service Monitoring (Linux Automation Project)

## 1. Project scope

SiteWatch is a Bash tool that checks configured websites and host:port services, writes history to CSV, calculates observed uptime percentage, remembers the latest status for each target, and logs an alert only when that target changes status. A systemd timer runs it automatically **every 3 minutes after the previous run**.

**Course environment:** Ubuntu Server **22.04 / 24.04**, or Rocky Linux 9. Ubuntu 26.04 is not one of the specified submission environments.

### Components and responsibility

| File | Role |
|---|---|
| `bin/sitewatch.sh` | **Main entrypoint**: options, CSV, state file, change-only alerts, logging |
| `bin/sitewatch-monitor.sh` | HTTP with curl, DNS with getent, TCP with nc, configurable UP/DOWN, timeout |
| `bin/sitewatch-report.sh` | Calculate observed uptime percentages from results.csv |
| `bin/sitewatch-run.sh` | Alias maintained for earlier integration (calls sitewatch.sh) |
| `config/sitewatch.conf` | Example URL and host:port targets, timeout, HTTP range, DATA_DIR |
| `systemd/sitewatch.service` | oneshot unit invoking the main script |
| `systemd/sitewatch.timer` | invoke every 3 minutes |
| `install.sh` / `uninstall.sh` | idempotent installer, clean service removal |
| `docs/report.pdf` | Report draft for the group to review |
| `docs/screenshots/` | Add your own real screenshots before submission |

## 2. Required tools

```bash
sudo apt update
sudo apt install -y curl netcat-openbsd git shellcheck python3
```

Bash, awk, sed, getent, flock, systemd and coreutils are normally included in Ubuntu Server.

## 3. Run locally before installing

```bash
git clone https://github.com/Teeraphat66050204/sitewatch.git
cd sitewatch
git switch Emergency-protocol

bash bin/sitewatch.sh -h
bash bin/sitewatch.sh -n -c config/sitewatch.conf
bash -n bin/*.sh install.sh uninstall.sh
shellcheck bin/*.sh install.sh uninstall.sh
```

`-n` validates and lists the targets but does not touch CSV/state.

To avoid needing root for a local test, override DATA_DIR:

```bash
SITEWATCH_DATA_DIR="$HOME/sitewatch-demo" bash bin/sitewatch.sh -v -c config/sitewatch.conf
cat "$HOME/sitewatch-demo/results.csv"
cat "$HOME/sitewatch-demo/state.tsv"
bash bin/sitewatch-report.sh "$HOME/sitewatch-demo/results.csv"
```

The sample config checks `https://example.com`, `example.com:443`, `http://127.0.0.1:8000` and `127.0.0.1:8000`. **Start the local web server** in a separate SSH session:

```bash
python3 -m http.server 8000 --bind 127.0.0.1
```

Repeat the monitoring command: the local URL/service should be **UP**. Stop the web server with Ctrl+C and repeat: the targets switch to **DOWN** and SiteWatch prints one `[WARN] ALERT` for each transition. Run again while DOWN: **no duplicate alerts**. Restart the web server and run again: `[INFO] RECOVERY` is logged.

## 4. Configuration

Edit `config/sitewatch.conf` before installation, or `/etc/sitewatch/sitewatch.conf` after installation.

```bash
URLS=("https://example.com" "http://127.0.0.1:8000")
SERVICES=("example.com:443" "127.0.0.1:8000")
TIMEOUT=5
HTTP_MIN=200
HTTP_MAX=399
DATA_DIR="/var/lib/sitewatch"
```

- `URLS`: an array of HTTP/HTTPS URLs (hostname, IPv4; optional port and path)
- `SERVICES`: an array of `hostname:port` TCP endpoints
- `TIMEOUT`: positive timeout in seconds (applies to curl and netcat)
- `HTTP_MIN`/`HTTP_MAX`: HTTP statuses considered healthy; by default 200–399
- `DATA_DIR`: absolute directory where CSV/state/lock files are written
- Environment `SITEWATCH_DATA_DIR` overrides the config for tests

**Security:** config is sourced as trusted Bash; do not accept arbitrary untrusted configs. No IPv6-bracket URL/host parsing is provided. Internet/DNS access is required for public targets.

## 5. Outputs / interpretation

`results.csv` records **every check** with:
`timestamp,type,target,dns,tcp,http_code,response_sec,status`.

`state.tsv` stores **only the latest** UP/DOWN status for each type/target. Initial observation does **not** create an alert (there was no previous state).

- URL UP when DNS resolves, TCP port accepts connection, and the final HTTP response lies within the configured range. Otherwise DOWN.
- Service UP when DNS resolves and the TCP port accepts connection. Otherwise DOWN.
- Response time measured via `curl -w %{time_total}`; a connection failure has HTTP 000.
- Uptime report: `100 × UP checks / all checks`. This measures **sampled uptime**, not exact availability continuously between checks.
- Logs with timestamps and `INFO`, `WARN`, `ERROR` go to stderr and, under systemd, to the journal.
- `-v` shows diagnostic details from the network checks; normal mode logs a short summary and only changes.

Exit status: **0** successful script execution (targets can still be DOWN), **1** operational/config error, **2** invalid command-line arguments.

## 6. Install and systemd timer

Run on a **new/disposable VM using one of the course-supported operating systems**:

```bash
sudo bash install.sh
systemctl list-timers --all | grep sitewatch
sudo systemctl start sitewatch.service
sudo systemctl status sitewatch.service
sudo journalctl -u sitewatch.service --no-pager -n 60
sudo /usr/local/lib/sitewatch/bin/sitewatch-report.sh /var/lib/sitewatch/results.csv
```

Files copied to `/usr/local/lib/sitewatch/bin/`, config to `/etc/sitewatch/sitewatch.conf`, unit files to `/etc/systemd/system/`, CSV/state to `/var/lib/sitewatch/`. Running `sudo bash install.sh` again is safe; existing config is preserved. The service uses `Type=oneshot`. The timer uses `OnBootSec=1min` and `OnUnitInactiveSec=3min`. Because the timer is monotonic and not calendar-based, `Persistent=true` is not needed.

**Failure demo (restore afterward):**

```bash
sudo mv /etc/sitewatch/sitewatch.conf /etc/sitewatch/sitewatch.conf.bak
sudo systemctl start sitewatch.service || true
sudo systemctl status sitewatch.service --no-pager
sudo journalctl -u sitewatch.service --no-pager -n 30
sudo mv /etc/sitewatch/sitewatch.conf.bak /etc/sitewatch/sitewatch.conf
sudo systemctl reset-failed sitewatch.service
```

Operational errors return code 1 and should leave the oneshot service in a failed state. A DOWN website is a valid monitoring result, so that does *not* fail the oneshot service.

## 7. Uninstall and data policy

```bash
sudo bash uninstall.sh --purge
```

`uninstall.sh` disables the timer and removes service units, installed scripts and config. `--purge` additionally deletes archived CSV/state. Without `--purge`, the data directory is deliberately retained for recovery. For a fully clean presentation demo, use `--purge` and verify:

```bash
systemctl list-timers --all | grep sitewatch || echo "No SiteWatch timer"
test ! -e /usr/local/lib/sitewatch && echo "Installed script removed"
test ! -e /var/lib/sitewatch && echo "Historical data purged"
```

## 8. Evidence required for course presentation

1. Fresh-VM install using `sudo bash install.sh`
2. `systemctl list-timers` and journal timestamps proving scheduling
3. Manual runs with `-h`, `-v`, `-n`
4. Web server on port 8000 toggled UP → DOWN → UP; only transition alerts
5. Missing-config error, exit status and failed oneshot status
6. CSV results, report uptime, latest-state file
7. `shellcheck` and `bash -n` outputs
8. Clean uninstall using `sudo bash uninstall.sh --purge`

For original member-1 output schema, see `docs/monitoring.md`. The draft PDF report documents the design; it must be reviewed with the group's names and real screenshots before final submission.

## 9. CI

GitHub Actions validates Bash syntax, ShellCheck, status transitions, uptime percentages and key error exits for this branch. Actual service/timer behavior should also be verified manually in the group's Ubuntu Server VM.
