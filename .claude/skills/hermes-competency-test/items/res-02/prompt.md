My WireGuard tunnel once black-holed large packets until I lowered its MTU, so I want to understand path MTU discovery properly. Look these up and answer:

1. Which RFC defines classic Path MTU Discovery for IPv4, and when was it published?
2. Which RFC is the current Path MTU Discovery standard for IPv6, when was it published, and which earlier RFC did it obsolete?
3. Which RFC introduced Packetization Layer Path MTU Discovery (PLPMTUD), and when?
4. Which RFC extended PLPMTUD to datagram transports such as UDP and QUIC, and when?
5. Why does classic PMTUD black-hole traffic when ICMP is filtered, and how does PLPMTUD avoid that?

Write the answer to `task/out/answer.md` in this format:

```
## Timeline
- RFC NNNN (Month YYYY): <what it did>
  (one bullet per RFC above, oldest first)

## Why black holes happen
<two or three sentences answering question 5>

## Sources
- <each URL you opened>
```

Keep everything above `## Sources` under 250 words, and only list sources you actually opened.
