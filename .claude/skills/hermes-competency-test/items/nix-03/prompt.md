Grafana won't come up on my NixOS box `atlas` after this morning's reboot; the dashboard just doesn't load. I exported the boot's journal to `task/journal.txt`. Find the root cause.

Write your diagnosis to `task/out/diagnosis.md` with exactly these three sections:

```
## Root cause
<one or two sentences>

## Evidence
<the journal lines that prove it, quoted exactly as they appear in the file>

## Fix
<the change to make in my NixOS configuration>
```
