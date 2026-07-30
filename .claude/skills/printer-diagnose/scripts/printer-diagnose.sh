#!/usr/bin/env bash
# Mechanical check battery for "printer not showing up" diagnosis.
# Usage: printer-diagnose.sh [printer-name-pattern]
# printer-name-pattern narrows the avahi/lpstat grep (defaults to a bare IPP scan).
# Runs locally — for a remote host, the skill prefixes this whole invocation
# with the resolved SSH command itself; this script has no host logic.
set -uo pipefail

PATTERN="${1:-}"

echo "--- avahi-browse (mDNS discovery, 3s scan) ---"
if [ -n "$PATTERN" ]; then
  avahi-browse -at 2>&1 | grep -i -E "ipp|$PATTERN" || echo "(no match for '$PATTERN' or IPP)"
else
  avahi-browse -at 2>&1 | grep -i "ipp" || echo "(no IPP entries found)"
fi

echo "--- cups-browsed.conf ---"
if [ -f /etc/cups/cups-browsed.conf ]; then
  if [ -s /etc/cups/cups-browsed.conf ]; then
    grep -i "CreateIPPPrinterQueues" /etc/cups/cups-browsed.conf || echo "(no CreateIPPPrinterQueues line found — compiled-in default LocalOnly applies)"
  else
    echo "(file exists but is EMPTY / 0 bytes — known stale-checkout bake bug)"
  fi
else
  echo "(file does not exist)"
fi

echo "--- lpstat: permanent queues ---"
lpstat -p -d 2>&1

echo "--- lpstat: discovered-but-not-queued ---"
lpstat -e 2>&1

echo "--- service state ---"
systemctl is-active cups-browsed avahi-daemon 2>&1

echo "--- recent avahi-daemon / cups-browsed journal (last 100 combined lines) ---"
journalctl -u cups-browsed -u avahi-daemon --no-pager -n 100 2>&1
