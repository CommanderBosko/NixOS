A friend sent me `task/modules/local-llm.nix`, a NixOS module they want me to add to my config.
It's not imported anywhere yet. Please review it before I use it.

- **Don't modify `task/modules/local-llm.nix`.** If you want to test-evaluate anything, work on a
  copy under `task/scratch/`.
- Write your findings to `task/out/review.md`, one finding per line, in exactly this form:

  `task/modules/local-llm.nix:<line> — <what's wrong and why> — <how to fix it>`

  `<line>` is the line number of the offending code in the original file.
- Only report real problems: things that fail to evaluate, don't do what the module's comments and
  option descriptions say they do, or create a security problem. No style nits. Don't pad the list.
  A short, correct review is better than a long one.

You can look things up in nixpkgs, for example the upstream NixOS module for a service. If you
claim something about how an option or the module system behaves, check it rather than guessing.
When you're done, give me a one-paragraph summary.
