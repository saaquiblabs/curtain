#!/bin/sh
# Measures the Mac's own power draw in each screen state, for the numbers on Curtain's page.
#
# Reads SystemPowerIn from the battery controller (ioreg AppleSmartBattery, milliwatts, no sudo):
# with the battery full and not charging, that is everything the Mac draws. It cannot see an
# external monitor's own draw (that needs a plug meter; the monitor maker's spec sheet covers
# sleep). macOS refreshes SystemPowerIn only about every 30 s, so each step lasts 3 minutes (about
# 6 fresh readings); the readings taken in the first 35 s after OK are marked settling (they still
# hold the click and the redraw). Steps alternate with Both on, so drift (other apps, heat) shows
# and cancels. Total CPU load is logged beside each sample. Screens stay awake (caffeinate).
# A first 60 s-per-step run (2026-11-25) gave one clean reading per step against a 2 W drift: too
# few to publish, hence this shape.
#
# Usage: Tools/measure-power.sh [out-dir]   (default docs/power). Curtain must be running.
set -eu
out=${1:-docs/power}
mkdir -p "$out"
stamp=$(date +%Y-%m-%dT%H%M)
csv="$out/desk-$stamp.csv"
settle=${SETTLE:-35}
samples=${SAMPLES:-180}

power() { ioreg -rn AppleSmartBattery | grep -oE '"SystemPowerIn"=[0-9]+' | head -1 | cut -d= -f2; }
charging() { ioreg -rn AppleSmartBattery | grep -oE '"IsCharging"=[0-9]+' | head -1 | cut -d= -f2; }
cpu() { ps -A -o %cpu= | awk '{s+=$1} END {printf "%.1f", s}'; }
ask() { osascript -e "display dialog \"$1\" with title \"Curtain power test\" buttons {\"OK\"} default button 1" >/dev/null; }

[ "$(charging)" = "0" ] || { echo "The battery is charging: wait until it's full, or the numbers include charging." >&2; exit 1; }
pgrep -x curtain >/dev/null || { echo "Curtain isn't running: make run first." >&2; exit 1; }

caffeinate -d -i -w $$ &
echo "step,second,system_power_mw,cpu_percent,settling" > "$csv"

step() { # name, instruction
  ask "$2"
  say -v Samantha "Measuring" 2>/dev/null || true
  i=1
  while [ "$i" -le "$samples" ]; do
    echo "$1,$i,$(power),$(cpu),$([ "$i" -le "$settle" ] && echo 1 || echo 0)" >> "$csv"
    sleep 1; i=$((i + 1))
  done
  say -v Samantha "Done" 2>/dev/null || true
}

on="Turn every screen on (Turn on, or Reconnect on the L27h-4A) at its usual brightness."
step both-on-1    "Step 1 of 7. Both screens on, at their usual brightness. Close Curtain's menu, keep your hands off the Mac (about 3 minutes), then click OK."
step macbook-off  "Step 2 of 7. In Curtain's menu, click Turn off on the MacBook. Close the menu, then click OK."
step both-on-2    "Step 3 of 7. $on Close the menu, then click OK."
step monitor-off  "Step 4 of 7. Click Turn off on the L27h-4A. Close the menu, then click OK."
step both-on-3    "Step 5 of 7. $on Close the menu, then click OK."
step monitor-disc "Step 6 of 7. Click Disconnect on the L27h-4A. Close the menu, then click OK."
step both-on-4    "Step 7 of 7. $on Close the menu, then click OK."

ask "All done. Thank you. Results are in $csv"
# Per step: the distinct fresh readings (macOS repeats a reading until it refreshes), their mean,
# and the mean CPU load.
awk -F, 'NR>1 && $5==0 {
    if (!($1 in o)) {o[$1]=++k; name[k]=$1}
    if ($3 != last[$1]) {s[$1]+=$3; n[$1]++; last[$1]=$3}
    c[$1]+=$4; m[$1]++ }
  END {for (i=1; i<=k; i++) {x=name[i]; printf "%-13s %6.2f W from %d readings   cpu %5.1f%%\n", x, s[x]/n[x]/1000, n[x], c[x]/m[x]}}' "$csv"
echo "$csv"
