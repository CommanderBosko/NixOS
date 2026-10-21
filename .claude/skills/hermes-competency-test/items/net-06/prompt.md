My laptop's WireGuard tunnel to the hub misbehaves since I'm at the cabin (its Wi-Fi comes from a
cellular router). Handshakes are fresh and `ssh` over the tunnel works fine for typing, but anything
big stalls: `scp` of a 50 MB file sits at a few KB, and web UIs over the tunnel load a blank page
and hang. I captured `wg show`, link info and some ping tests on the laptop:
`task/captures.txt`. The laptop's tunnel config is `task/wireguard.nix`.

You can't reach the laptop or the hub from here, so work only from these files. Don't edit
either of them.

1. Write the config change you recommend as a unified diff against `task/wireguard.nix` to
   `task/out/mtu.diff`. It must apply cleanly with `patch`, and the result must still be valid Nix.
2. In your reply, explain what's wrong and how you got your number from the captures.
