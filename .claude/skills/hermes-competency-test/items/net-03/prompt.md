Devices on my tailnet can't open the family status page on this machine: http://gaming:18473/ fails
with a connection error, when it should show the status page. The service is running right now
from the systemd unit copied to `task/status-page.service`; the page's files are in `task/www/`.

Find out why using live, read-only checks on this machine, then:

1. Write the fix as a unified diff against `task/status-page.service` to `task/out/fix.diff`. I'll
   apply it myself, so it must apply cleanly with `patch`. Keep the change minimal.
2. Write `task/out/diagnosis.md`: what's wrong, the commands you ran and what they showed, and
   anything outside the unit file that would also need to change before tailnet devices can get
   through (describe it, don't change it).

Don't edit `task/status-page.service`, and don't stop, restart, kill or re-launch the running
service or any other process.
