Please review the firewall settings in `task/networking.nix` before I copy them into my config. The
comment at the top says what's supposed to be reachable from where; check that the settings
actually do that, and that nothing in the file breaks the other features it describes.

1. Write a unified diff against `task/networking.nix` that fixes every problem you find to
   `task/out/firewall.diff`. It must apply cleanly with `patch`, the result must still be valid
   Nix, and it shouldn't change anything that's already right.
2. Write `task/out/review.md` with one bullet per problem: what's wrong, why it matters, and what
   your diff does about it.

Don't edit `task/networking.nix` itself.
