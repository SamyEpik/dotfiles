#!/bin/sh
# Detect an ACPI GPE 6D storm and clear the stuck PME status bit on the I219.

GPE=/sys/firmware/acpi/interrupts/gpe6D
DEV=00:1f.6
THRESHOLD=1000 # events per second that count as a storm

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0"
  exit 1
fi

count() {
  read -r c _ <"$GPE"
  echo "$c"
}

measure() {
  a=$(count)
  sleep 1
  b=$(count)
  echo $((b - a))
}

rate=$(measure)
echo "GPE 6D rate: $rate events/s"

if [ "$rate" -le "$THRESHOLD" ]; then
  echo "No storm detected, nothing to do."
  exit 0
fi

st=$(setpci -s "$DEV" CAP_PM+4.w)
if [ $((0x$st & 0x8000)) -eq 0 ]; then
  echo "Storm detected, but PME status is not set on $DEV."
  echo "The source is something else, so I'm not touching anything."
  exit 2
fi

echo "Storm detected and PME status is set on $DEV, clearing it."
setpci -s "$DEV" CAP_PM+4.w=8000:8000

rate=$(measure)
echo "GPE 6D rate after clear: $rate events/s"
if [ "$rate" -le "$THRESHOLD" ]; then
  echo "Storm stopped."
else
  echo "Still storming, so something else is asserting the GPE."
  exit 3
fi
