#!/usr/bin/env bash
# set-tuned.sh <profile>
# Sets tuned-adm profile and wakes eww TUNED_PROFILE deflisten.

PROFILE="$1"
[ -z "$PROFILE" ] && exit 1

mkdir -p /tmp/eww

# Apply tuned profile
sudo tuned-adm profile "$PROFILE"

# Update cache and wake deflisten
echo "$PROFILE" > /tmp/eww/tuned_profile
echo "$PROFILE" >> /tmp/eww/tuned_profile_trigger
