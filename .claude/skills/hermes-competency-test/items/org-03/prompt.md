Please triage my mail. It's in `task/mail/`, a Maildir (`cur/` and `new/`, one message per file). Assume today is Tuesday 20 October 2026.

1. Write `task/out/triage.md` with four sections in this order: `## Urgent`, `## This week`, `## Later`, `## Ignore`. Put every message in exactly one section, one line per message. Start each line with the message's Message-ID (for example `<abc123@example.com>`), then a few words on why it's there. If anything looks like phishing or a scam, say so explicitly on its line.
2. For each message in Urgent, write a reply draft as its own file in `task/out/drafts/` (for example `task/out/drafts/reply-1.md`). Each draft starts with a `To:` line and a `Subject:` line, then the body.

Don't send anything, and don't change anything in `task/mail/`.
