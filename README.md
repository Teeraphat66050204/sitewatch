# SiteWatch – Linux Automation Project

**Emergency integration branch** (`backup/demo-integration`) for the group presentation. The monitoring module was developed on `feature/monitoring`; this branch adds a fallback implementation for the remaining components. **It is not merged into main.**

## Components

- `bin/sitewatch.sh`: member 1, HTTP/DNS/TCP checks, supports `-h -c -v -n`
- `bin/sitewatch-run.sh`: integration wrapper, CSV, state file, alerts on transitions only
- `bin/sitewatch-report.sh`: observed uptime per target (UP checks / all checks * 100)
- `config/sitewatch.conf`: URLs, host:port, timeout, HTTP success range
- `systemd/sitewatch.service`: oneshot service
- `systemd/sitewatch.timer`: recurring every 3 minutes
- `install.sh` and `uninstall.sh`: install, enable timer, cleanly remove

## Local (without installing a system service)

```bash
sudo apt update
sudo apt install -y curl netcat-openbsd git shellcheck python3
shellcheck bin/*.sh install.sh uninstall.sh
bash -n bin/sitewatch.sh bin/sitewatch-run.sh bin/sitewatch-report.sh install.sh uninstall.sh

# The default config checks a local site on 127.0.0.1:8000
python3 -m http.server 8000 --bind 127.0.0.1
# Open a second terminal in the same directory:
SITEWATCH_DATA_DIR="$HOME/sitewatch-data" bash bin/sitewatch-run.sh -v -c config/sitewatch.conf
cat "$HOME/sitewatch-data/results.csv"
SITEWATCH_DATA_DIR="$HOME/sitewatch-data" bash bin/sitewatch-report.sh
```

Stop the Python server with Ctrl+C, run the wrapper again to see `ALERT UP -> DOWN`. Run it once more while DOWN: there should be **no repeated alert**. Restart the Python server and check again to see `RECOVERY DOWN -> UP`.

To clear local history before a demo: `rm -rf "$HOME/sitewatch-data"` (this **deletes test records**).

## Install and test systemd

**Use a throwaway Ubuntu Server VM**. The course PDF specifies Ubuntu Server 22.04/24.04 or Rocky Linux 9 (not Ubuntu 26.04).

```bash
sudo bash install.sh
systemctl list-timers --all | grep sitewatch
sudo systemctl start sitewatch.service
sudo systemctl status sitewatch.service
sudo journalctl -u sitewatch.service --no-pager -n 50
sudo head -n 5 /var/lib/sitewatch/results.csv
sudo /usr/local/lib/sitewatch/bin/sitewatch-report.sh
```

If installed sitewatch monitoring targets need changing, edit `/etc/sitewatch/sitewatch.conf`. The installer preserves any existing config.

```bash
sudo bash uninstall.sh
# Optional: also delete stored CSV/state:
sudo bash uninstall.sh --purge
```

The default service runs as root on a controlled demo VM to access `/var/lib/sitewatch`. Keep the project config trusted; it is sourced as Bash code. For production, use a dedicated restricted service user and locked-down directories.

## Script behavior and exit status

`sitewatch-run.sh` and `sitewatch.sh` both accept `-h`, `-c`, `-v`, `-n`. Codes: 0=executed, 1=missing/broken configuration or environment, 2=invalid arguments. A monitored DOWN target does not make the service fail, since monitoring succeeded. A missing config should make `systemctl status sitewatch.service` show failed.

The `results.csv` file stores a timestamped row for every target per run. The `state.tsv` file stores the **latest** status per target. Alerts appear on stderr (and the systemd journal) only when a previously seen target changes status. On the first run there is no previous status, so there is no alert.

Uptime is based on observed **checks**, not precise continuous availability between runs.

## Handover

This is a **fallback draft** prepared separately so teammates can review or replace these components without overwriting their ongoing work. It still needs full ShellCheck, install/uninstall, timer and UP/DOWN demonstration on the team's actual Ubuntu 24.04 or Rocky Linux 9 VM before submission.

See `docs/monitoring.md` for the member-1 TSV output format. Add the final `docs/report.pdf` and `docs/screenshots/` before submission.
