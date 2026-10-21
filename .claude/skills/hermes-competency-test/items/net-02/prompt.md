On this machine (gaming), which DNS server actually answers lookups for (a) normal internet names
like example.com and (b) tailnet names like `laptop`? Is my pi-hole in that path, and if so, how
does a query get to it?

Prove it with commands you run here. Don't rely on notes, memory or config files alone, since the
live setup can differ from what's written down. This is read-only: don't change any DNS, Tailscale
or network settings.

Write `task/out/dns.md` with exactly these four sections:

## Normal names
The resolver this machine sends the query to first (by IP), and where the query goes from there
(by IP).

## Tailnet names
What answers tailnet names, and the tailnet's DNS suffix.

## Pi-hole in path?
Start with `Yes` or `No`, then one or two sentences on how.

## Evidence
The commands you ran and the key output lines behind each claim above.
