#!/usr/bin/env bash
# Project: SiteWatch - Website & Service Monitoring
# Member Name 1: [รายชื่อสมาชิก 1]
# Member Name 2: [รายชื่อสมาชิก 2]
# Member Name 3: [รายชื่อสมาชิก 3]
# Member Name 4: [รายชื่อสมาชิก 4]
# Calculate observed uptime percentages from the stored CSV records.
set -euo pipefail
CSV_FILE="${1:-${SITEWATCH_DATA_DIR:-/var/lib/sitewatch}/results.csv}"
[[ -r "$CSV_FILE" ]] || { printf 'Cannot read CSV: %s\n' "$CSV_FILE" >&2; exit 1; }
awk '
function field(line, wanted,   i,c,nextc,inside,num,out) {
    inside=0; num=1; out=""
    for (i=1; i<=length(line); i++) {
        c=substr(line,i,1); nextc=substr(line,i+1,1)
        if (c=="\"") {
            if (inside && nextc=="\"") { out=out "\""; i++ }
            else { inside=!inside }
        } else if (c=="," && !inside) {
            if (num==wanted) return out
            num++; out=""
        } else { out=out c }
    }
    if (num==wanted) return out
    return ""
}
NR==1 { next }
{
    type=field($0,2)
    target=field($0,3)
    status=field($0,8)
    if (type=="" || target=="" || (status!="UP" && status!="DOWN")) next
    key=type SUBSEP target
    name[key]=type " " target
    total[key]++
    if (status=="UP") up[key]++
    all++
    if (status=="UP") all_up++
}
END {
    printf "Target\tUP\tChecks\tUptime(%%)\n"
    for (key in total) printf "%s\t%d\t%d\t%.2f\n",name[key],up[key],total[key],100*up[key]/total[key]
    if (all) printf "OVERALL\t%d\t%d\t%.2f\n",all_up,all,100*all_up/all
}' "$CSV_FILE"
