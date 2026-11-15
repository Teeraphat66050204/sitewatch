# SiteWatch — Website & Service Monitoring System
---

## Project Members

| ลำดับ | รหัสนักศึกษา | ชื่อ - นามสกุล |
|---|---|---|
| 1 | 66050204 | ธีรภัทร ผลเจริญ |
| 2 | 66050033 | กิตติคุณ จรูมเคลือ |
| 3 | 66050398 | ศรุต สูงสุมาลย์|

**รายวิชา:** Linux system and Operation 
**หัวข้อโครงงาน:** SiteWatch — Website & Service Monitoring System

---

## 1. บทนำ (Introduction)
## Introduction

SiteWatch เป็นระบบตรวจสอบและเฝ้าระวังสถานะของเว็บไซต์ (Website) และบริการเครือข่าย (Network Services) ที่พัฒนาด้วยภาษา Bash Script บนระบบปฏิบัติการ Linux โดยมีวัตถุประสงค์เพื่อตรวจสอบความพร้อมในการให้บริการของเว็บไซต์และพอร์ตเครือข่าย รวมถึงบันทึกผลการตรวจสอบเพื่อนำไปวิเคราะห์ความพร้อมใช้งานของระบบ (Uptime)

ระบบสามารถตรวจสอบสถานะของ DNS, TCP Port และ HTTP Response พร้อมบันทึกข้อมูลในรูปแบบ CSV และแจ้งเตือนเมื่อสถานะของบริการมีการเปลี่ยนแปลง เช่น จาก UP เป็น DOWN หรือจาก DOWN เป็น UP


## Project Structure

โครงงานจัดแบ่งไฟล์ออกเป็นหมวดหมู่ตามหน้าที่การทำงาน ดังนี้

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

**รายละเอียดของไฟล์และไดเรกทอรี**

| ไฟล์ / ไดเรกทอรี | หน้าที่ |
|---|---|
| `README.md` | เอกสารแนะนำและวิธีใช้งานโครงงาน |
| `bin/sitewatch.sh` | สคริปต์หลักสำหรับตรวจสอบและประมวลผล |
| `config/sitewatch.conf` | ไฟล์กำหนดค่าเว็บไซต์และบริการที่ต้องการตรวจสอบ |
| `systemd/sitewatch.service` | กำหนดการทำงานของระบบผ่าน systemd |
| `systemd/sitewatch.timer` | กำหนดรอบเวลาการตรวจสอบอัตโนมัติ |
| `install.sh` | สคริปต์สำหรับติดตั้งระบบ |
| `uninstall.sh` | สคริปต์สำหรับถอนการติดตั้งระบบ |
| `docs/report.pdf` | รายงานประกอบโครงงาน |
| `docs/screenshots/` | จัดเก็บภาพประกอบการทดสอบระบบ |

## Requirements)

### ระบบปฏิบัติการ

ระบบรองรับระบบปฏิบัติการ Linux ดังต่อไปนี้

- Ubuntu Server 22.04 LTS
- Ubuntu Server 24.04 LTS
- Rocky Linux 9


### โปรแกรมและเครื่องมือที่จำเป็น

| โปรแกรม | วัตถุประสงค์ |
|---|---|
| Bash | ใช้เขียนและเรียกใช้งาน Shell Script |
| curl | ตรวจสอบ HTTP Status Code และ Response Time |
| netcat (nc) | ตรวจสอบการเชื่อมต่อ TCP Port |
| getent | ตรวจสอบการแปลงชื่อ Domain Name |
| ShellCheck | ตรวจสอบข้อผิดพลาดและคุณภาพของ Shell Script |
| Git | จัดการ Source Code |
| Python 3 | รองรับงานประมวลผลหรือเครื่องมือที่เกี่ยวข้อง |

### การติดตั้ง Dependencies บน Ubuntu

ดำเนินการติดตั้งโปรแกรมที่จำเป็นด้วยคำสั่งต่อไปนี้

```bash
sudo apt update
sudo apt install -y curl netcat-openbsd shellcheck git python3
```

## System Features

ระบบ SiteWatch ประกอบด้วยความสามารถหลักดังต่อไปนี้

### DNS Monitoring

ตรวจสอบว่า Domain Name สามารถแปลงเป็น IP Address ได้หรือไม่ โดยใช้คำสั่ง `getent`

### TCP Port Monitoring

ตรวจสอบว่าสามารถเชื่อมต่อไปยังพอร์ตของบริการที่กำหนดได้หรือไม่ โดยใช้คำสั่ง `nc`

### HTTP Monitoring

ตรวจสอบเว็บไซต์ผ่าน HTTP หรือ HTTPS โดยใช้ `curl` เพื่อเก็บข้อมูลดังต่อไปนี้

- HTTP Status Code
- HTTP Response Time
- สถานะการเข้าถึงเว็บไซต์

### Uptime Calculation

บันทึกผลการตรวจสอบลงในไฟล์ CSV และนำข้อมูลมาคำนวณเปอร์เซ็นต์ Uptime เพื่อประเมินความพร้อมใช้งานของบริการ

### Status Change Notification

ตรวจสอบความเปลี่ยนแปลงของสถานะบริการ และแจ้งเตือนเมื่อสถานะเปลี่ยนแปลง เช่น

- UP → DOWN
- DOWN → UP

ระบบจะไม่แจ้งเตือนซ้ำหากสถานะยังคงเดิม

### Automated Monitoring

ใช้ systemd Service และ Timer เพื่อกำหนดให้ระบบทำงานตามรอบเวลาที่ตั้งค่าไว้โดยอัตโนมัติ

## Configuration

ก่อนเริ่มใช้งาน สามารถกำหนดเว็บไซต์และบริการที่ต้องการตรวจสอบได้จากไฟล์

```text
config/sitewatch.conf
```

ตัวอย่างการกำหนดค่า

```bash
URLS=("https://example.com" "http://127.0.0.1:8000")
SERVICES=("example.com:443" "127.0.0.1:8000")

TIMEOUT=5
HTTP_MIN=200
HTTP_MAX=399

DATA_DIR="/var/lib/sitewatch"
```

**คำอธิบายตัวแปร**

| ตัวแปร | รายละเอียด |
|---|---|
| `URLS` | รายการเว็บไซต์ที่ต้องการตรวจสอบ |
| `SERVICES` | รายการ Host และ TCP Port ที่ต้องการตรวจสอบ |
| `TIMEOUT` | ระยะเวลาสูงสุดที่อนุญาตให้ตรวจสอบ |
| `HTTP_MIN` | HTTP Status Code ต่ำสุดที่ถือว่าปกติ |
| `HTTP_MAX` | HTTP Status Code สูงสุดที่ถือว่าปกติ |
| `DATA_DIR` | ตำแหน่งจัดเก็บไฟล์ผลการตรวจสอบ |

สามารถแก้ไขไฟล์ตั้งค่าได้ 2 ตำแหน่ง ได้แก่

- ก่อนติดตั้ง: `config/sitewatch.conf`
- หลังติดตั้ง: `/etc/sitewatch/sitewatch.conf`

## Installation

### 7.1 ติดตั้งระบบ

เข้าไปยังไดเรกทอรีหลักของโครงงาน แล้วเรียกใช้งาน Install Script

```bash
sudo chmod +x install.sh
sudo ./install.sh
```

สคริปต์จะดำเนินการติดตั้งไฟล์และตั้งค่าระบบตามที่กำหนดไว้ใน Install Script

### เริ่มต้นการทำงาน

สั่งให้ systemd เริ่มทำงานผ่านคำสั่ง

```bash
sudo systemctl start sitewatch.service
```

### ตรวจสอบสถานะ Timer

ตรวจสอบว่าระบบตั้งเวลาทำงานอัตโนมัติหรือไม่

```bash
systemctl list-timers --all | grep sitewatch
```

### ตรวจสอบ Log

ตรวจสอบประวัติการทำงานของระบบผ่าน Journalctl

```bash
sudo journalctl -u sitewatch.service -n 30 --no-pager
```

### เรียกใช้งานระบบด้วยตนเอง

สามารถสั่งให้ระบบตรวจสอบเป้าหมายได้โดยตรงด้วยคำสั่ง

```bash
sudo bash /usr/local/lib/sitewatch/bin/sitewatch.sh \
  -c /etc/sitewatch/sitewatch.conf
```

### ตรวจสอบคู่มือการใช้งาน

```bash
bash bin/sitewatch.sh -h
```

ใช้แสดงรายละเอียดคำสั่งและตัวเลือกที่ระบบรองรับ

### ทดสอบ Dry Run

```bash
bash bin/sitewatch.sh -n -c config/sitewatch.conf
```

ใช้ตรวจสอบกระบวนการทำงานเบื้องต้นโดยไม่ดำเนินการเปลี่ยนแปลงข้อมูลจริง

### ทดสอบการตรวจสอบเว็บไซต์

```bash
SITEWATCH_DATA_DIR="$HOME/sitewatch-demo" \
bash bin/sitewatch.sh -v -c config/sitewatch.conf
```

ใช้ตรวจสอบการทำงานพร้อมแสดงรายละเอียดเพิ่มเติม (Verbose Mode)

### ทดสอบการสร้างรายงาน Uptime

```bash
SITEWATCH_DATA_DIR="$HOME/sitewatch-demo" \
bash bin/sitewatch.sh -r -c config/sitewatch.conf
```

ใช้สร้างรายงาน Uptime จากข้อมูลที่บันทึกไว้ โดยไม่ดำเนินการตรวจสอบเป้าหมายรอบใหม่

### ตรวจสอบไฟล์ผลลัพธ์

```bash
cat "$HOME/sitewatch-demo/results.csv"
cat "$HOME/sitewatch-demo/state.tsv"
cat "$HOME/sitewatch-demo/sitewatch.log"
```

ไฟล์ผลลัพธ์ประกอบด้วย

| ไฟล์ | รายละเอียด |
|---|---|
| `results.csv` | จัดเก็บประวัติผลการตรวจสอบในรูปแบบ CSV |
| `state.tsv` | จัดเก็บสถานะล่าสุดของแต่ละบริการ |
| `sitewatch.log` | จัดเก็บข้อความบันทึกการทำงานของระบบ |

## ตัวเลือกการใช้งาน (Command-Line Options)

ระบบรองรับตัวเลือกสำหรับควบคุมการทำงานดังต่อไปนี้

| ตัวเลือก | รายละเอียด |
|---|---|
| `-h` | แสดงคู่มือการใช้งาน |
| `-c FILE` | ระบุไฟล์ Configuration |
| `-v` | แสดงรายละเอียดการทำงานเพิ่มเติม |
| `-n` | ทำงานในโหมด Dry Run |
| `-r` | สร้างรายงาน Uptime จากข้อมูลเดิมโดยไม่ตรวจสอบรอบใหม่ |

### Exit Codes

รหัสสถานะการทำงานของโปรแกรมมีรายละเอียดดังนี้

| Exit Code | ความหมาย |
|---|---|
| `0` | การตรวจสอบทำงานสำเร็จ แม้บางเป้าหมายจะมีสถานะ DOWN |
| `1` | เกิดข้อผิดพลาดเกี่ยวกับ Configuration หรือ Runtime |
| `2` | มีการใช้งานคำสั่งหรือส่ง Argument ไม่ถูกต้อง |

### Logging

ระบบบันทึกข้อความการทำงานโดยแบ่งระดับความสำคัญออกเป็น 3 ระดับ ได้แก่

- `INFO` — รายงานข้อมูลการทำงานทั่วไป
- `WARN` — แจ้งเตือนเกี่ยวกับเหตุการณ์ที่ควรตรวจสอบ
- `ERROR` — รายงานข้อผิดพลาดที่เกิดขึ้น

โดยบันทึกข้อมูลลงใน Standard Error, systemd Journal และไฟล์ `sitewatch.log` ระหว่างการทำงานตามปกติ

## Uninstallation

หากต้องการถอนการติดตั้งระบบ สามารถเรียกใช้งาน Uninstall Script ได้ด้วยคำสั่ง

```bash
sudo bash uninstall.sh
```

หากต้องการถอนการติดตั้งโดยเก็บข้อมูลผลการตรวจสอบเดิมไว้ ให้ใช้คำสั่ง

```bash
sudo bash uninstall.sh --keep-data
```

ตัวเลือก `--keep-data` ใช้สำหรับเก็บรักษาไฟล์ Log และข้อมูลผลการตรวจสอบไว้หลังจากถอนการติดตั้ง