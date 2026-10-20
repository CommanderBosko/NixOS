Audit what on this machine (gaming) other machines could connect to: every TCP or UDP socket
that's listening on an address other than loopback (127.0.0.0/8 or ::1). Use live checks. No sudo,
and this is read-only: don't stop services or touch the firewall.

Write `task/out/ports.md` with:

1. A Markdown table with exactly these columns:

   | Port | Proto | Address | Process | Expected? |

   One row per port and protocol listening on a non-loopback address. The Port column holds just
   the number. If you can't tell which process owns a socket, write `unknown`, with your best guess
   in brackets if you have one, e.g. `unknown (likely jellyfin)`.

2. A section `## Unexpected` with one bullet per thing that looks unintended or more exposed than it
   needs to be, each with the reason. Write `None` if nothing qualifies.
