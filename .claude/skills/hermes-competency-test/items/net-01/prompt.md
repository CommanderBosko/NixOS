Which devices on my tailnet are offline right now, and when was each one last seen?

Check the live state from this machine (gaming). Don't go by notes, memory or config files, since
devices come and go. This is read-only: don't change any Tailscale settings.

Write the answer to `task/out/offline.md` as a Markdown table with exactly these columns:

| Device | Last seen (UTC) | OS |

- One row per offline device, with the device's Tailscale machine name in the Device column.
- Last seen as `YYYY-MM-DD HH:MM`, in UTC.
- Don't list devices that are online, and don't list this machine.
- If no device is offline, keep the header row and write `No devices are offline.` on the line
  below the table.

Then reply with a one-line summary: how many devices are offline, out of how many in total.
