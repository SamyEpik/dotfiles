#!/bin/sh

msg=$(printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

case "$msg" in
"")
  ;; # empty: print nothing
"Scan fingerprint to unlock" | "Scanning...")
  echo "$msg" # keep these unchanged
  ;;
*)
  echo "Retry to scan fingerprint" # replace everything else
  ;;
esac
