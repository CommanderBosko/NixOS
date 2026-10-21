The household status page on {{TARGET}} isn't answering. It's a user-level systemd service,
`hc-status.service`, running under my user (no root involved), and it should serve a small page on
127.0.0.1:18474 on {{TARGET}}. From gaming I normally open it through an SSH tunnel:
`ssh -N -L 18474:127.0.0.1:18474 {{SSH}}`, then `curl http://127.0.0.1:18474/`. Right now that
gets nothing.

You may ssh to {{SSH}} for this, and only that host. I'll approve each command before it runs.

1. Diagnose with read-only commands first, and tell me what's wrong before you change anything.
2. Apply the smallest fix to that one user unit, then restart only that unit with
   `systemctl --user`. No sudo, no system services, no firewall or network changes, and don't
   touch any other file, unit or process.
3. Prove it works with curl run from gaming, either through the tunnel above or with
   `ssh {{SSH}} curl ...`, and show me the output. Don't leave a tunnel running afterwards.
4. Finish with a short summary: the cause, the exact change, and how you verified it.
