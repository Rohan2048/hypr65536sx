#!/usr/bin/env bash
# set-governor.sh <governor>
# Sets CPU governor for all cores and wakes eww CPU_GOVERNOR deflisten.

GOVERNOR="$1"
[ -z "$GOVERNOR" ] && exit 1

mkdir -p /tmp/eww

# Apply to all CPU cores
for CPU in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
    echo "$GOVERNOR" | sudo tee "$CPU" > /dev/null
done

# Update cache and wake deflisten
echo "$GOVERNOR" > /tmp/eww/cpu_governor
echo "$GOVERNOR" >> /tmp/eww/cpu_governor_trigger
