Since this morning my laptop can still reach gaming and the pi-hole over Tailscale, but no website
loads. Wi-Fi says connected, and the phones on the same Wi-Fi are fine. I captured some output on
the laptop: it's in `task/laptop-captures.txt`.

You can't reach the laptop from here, so work only from the captures. Don't edit that file.

Write `task/out/diagnosis.md` with exactly these three sections:

## Root cause
One short paragraph: what's actually wrong.

## Evidence
Bullets quoting the specific capture lines that prove it, and anything in the captures that looks
suspicious but isn't the cause.

## Proposed commands
The commands I should run on the laptop, in order, to fix it and then confirm the fix, each in a
code block with a one-line comment. Don't run anything yourself.
