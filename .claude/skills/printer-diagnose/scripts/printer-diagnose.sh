#!/usr/bin/env bash
# Mechanical check battery for "printer not showing up / nothing prints" diagnosis.
# Usage: printer-diagnose.sh [printer-name-pattern]
# printer-name-pattern narrows the avahi grep (defaults to a bare IPP scan).
# Runs locally — for a remote host, the skill prefixes this whole invocation
# with the resolved SSH command itself; this script has no host logic.
set -uo pipefail

PATTERN="${1:-}"

# No -t: `avahi-browse -t` exits on avahi's "all for now" signal, which can
# fire before the printer answers — a false "no IPP entries" (seen 2026-09-23).
# Collect for a fixed window instead; `|| true` stops timeout's exit 124 from
# failing the pipeline under pipefail and printing a bogus "no entries" line.
echo "--- avahi-browse (mDNS discovery, 5s scan) ---"
if [ -n "$PATTERN" ]; then
  { timeout 5 avahi-browse -a 2>&1 || true; } | grep -i -E "ipp|$PATTERN" || echo "(no match for '$PATTERN' or IPP)"
else
  { timeout 5 avahi-browse -a 2>&1 || true; } | grep -i "ipp" || echo "(no IPP entries found)"
fi

echo "--- ippfind (IPP printers CUPS itself can reach) ---"
timeout 8 ippfind 2>&1 || echo "(ippfind found nothing / failed, exit $?)"

echo "--- lpstat: permanent queues + device URIs ---"
lpstat -p -d 2>&1
lpstat -v 2>&1

echo "--- queue drivers (PPD NickName per queue) ---"
for q in $(lpstat -v 2>/dev/null | sed -n 's/^device for \([^:]*\):.*/\1/p'); do
  nick=$(grep -h '^\*NickName' "/etc/cups/ppd/$q.ppd" 2>/dev/null || echo "(no PPD readable at /etc/cups/ppd/$q.ppd)")
  echo "$q: $nick"
done

echo "--- lpstat -e: all destinations, incl. DNS-SD-discovered ones with no queue ---"
lpstat -e 2>&1

echo "--- jobs: pending, then last 5 completed ---"
lpstat -o 2>&1
lpstat -W completed -o 2>&1 | tail -5

echo "--- per-user default overrides (~/.cups/lpoptions) ---"
cat ~/.cups/lpoptions 2>/dev/null || echo "(none for $USER)"

echo "--- service state (cups, avahi-daemon) ---"
systemctl is-active cups avahi-daemon 2>&1

echo "--- recent cups journal: jobs, queue changes, errors (last 40 matches, this boot) ---"
journalctl -u cups -b --no-pager -o short 2>&1 \
  | grep -E 'Queued on|Job completed|Job stopped|New printer|deleted by|Unable|rror|Started (filter|backend)' \
  | tail -40
