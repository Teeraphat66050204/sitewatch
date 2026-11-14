# SiteWatch — Website & Service Monitoring

Linux Automation Project, **Topic 4**. This is the single-script edition matching the course's suggested folder structure. **All monitoring and processing logic is inside `bin/sitewatch.sh`.**

## Repository structure

```text
sitewatch/
├── README.md
├── bin/
│   └── sitewatch.sh
├── config/
│   └── sitewatch.conf
├── systemd/
│   ├── sitewatch.service
│   └── sitewatch.timer
├── install.sh
├── uninstall.sh
└── docs/
    ├── report.pdf
    └── screenshots/
```

## OS and dependencies

Use **Ubuntu Server 22.04 or 24.04** or **Rocky Linux 9** as specified in the course PDF. The earlier demo VM used Ubuntu 26.04.1, which is not one of the specified systems.

Ubuntu setup:

```bash
sudo apt update
sudo apt install -y curl netcat-openbsd shellcheck git python3
```

## Configuration

Edit `config/sitewatch.conf` before installation or `/etc/sitewatch/sitewatch.conf` afterwards. It is **trusted Bash syntax** loaded with `source`, so do not accept arbitrary config files from other users.

```bash
URLS=("https://example.com" "http://127.0.0.1:8000")
SERVICES=("example.com:443" "127.0.0.1:8000")
TIMEOUT=5
HTTP_MIN=200
HTTP_MAX=399
DATA_DIR="/var/lib/sitewatch"
```

URL is UP when DNS resolves, TCP connects, and HTTP status is within `HTTP_MIN..HTTP_MAX` (200–399 by default). Service is UP when DNS resolves and TCP connects. DNS uses `getent`, TCP uses `nc`, HTTP status and response time use `curl`. No IPv6 bracket-form parsing.

## Run manually

```bash
bash -n bin/sitewatch.sh install.sh uninstall.sh
shellcheck bin/sitewatch.sh install.sh uninstall.sh
bash bin/sitewatch.sh -h
bash bin/sitewatch.sh -n -c config/sitewatch.conf
SITEWATCH_DATA_DIR="$HOME/sitewatch-demo" bash bin/sitewatch.sh -v -c config/sitewatch.conf
SITEWATCH_DATA_DIR="$HOME/sitewatch-demo" bash bin/sitewatch.sh -r -c config/sitewatch.conf
cat "$HOME/sitewatch-demo/results.csv"
cat "$HOME/sitewatch-demo/state.tsv"
cat "$HOME/sitewatch-demo/sitewatch.log"
```

Options: `-h` help; `-c FILE` config; `-v` verbose; `-n` dry-run (no changes); **`-r`** sampled uptime report without a new check.

Exit codes: 0 successful monitoring (targets may be DOWN), 1 configuration/runtime error, 2 usage error. Logs include time and INFO/WARN/ERROR levels, written to stderr, journal and `DATA_DIR/sitewatch.log` during normal runs.

## UP / DOWN / Alert demonstration

Open a second SSH terminal:

```bash
python3 -m http.server 8000 --bind 127.0.0.1
```

Run SiteWatch with `-v`, stop the server with Ctrl+C, run again (DOWN and WARN ALERT), run once more (no duplicate alert), restart the server and run again (UP and INFO RECOVERY). `state.tsv` records current status. `results.csv` saves timestamp, type, target, DNS, TCP, HTTP code, response seconds, and status. Uptime = 100 × UP checks / total checks (**sampled uptime**, not continuously measured).

## Install, schedule and uninstall

```bash
sudo bash install.sh
sudo systemctl start sitewatch.service
systemctl list-timers --all | grep sitewatch
sudo journalctl -u sitewatch.service -n 30 --no-pager
sudo bash /usr/local/lib/sitewatch/bin/sitewatch.sh -r -c /etc/sitewatch/sitewatch.conf
sudo cat /var/lib/sitewatch/results.csv
```

The systemd oneshot runs every **3 minutes after a completed run**; `Deactivated successfully` is normal. The installer can be rerun and preserves existing config. To demonstrate a service error, temporarily move `/etc/sitewatch/sitewatch.conf`, start the service, check its status, then restore the file and reset failed state.

After taking screenshots:

```bash
sudo bash uninstall.sh
systemctl list-timers --all | grep sitewatch || echo "Timer removed"
```

Uninstall removes the installed files and recorded data. Use `--keep-data` to preserve results.

## Submission

Replace the student-name placeholders in the three Bash scripts with the actual group members. Add authentic screenshots to `docs/screenshots/`, and finish `docs/report.pdf` with the real names, screenshots, and OS-compliant demonstration results. Avoid claiming the Ubuntu 26.04.1 VM meets the course's OS requirement.
