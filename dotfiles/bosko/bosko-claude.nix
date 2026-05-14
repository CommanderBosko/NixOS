{ self, ... }:

{
  home.file = {
    ".claude/agents/repo-creator-agent.md" = {
      source = "${self}/dotfiles/bosko/claude/agents/repo-creator-agent.md";
      force = true;
    };
    ".claude/agents/session-closer.md" = {
      source = "${self}/dotfiles/bosko/claude/agents/session-closer.md";
      force = true;
    };
  };
}
