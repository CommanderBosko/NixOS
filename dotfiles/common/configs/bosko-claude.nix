{ self, ... }:

{
  home.file = {
    ".claude/agents/repo-creator-agent.md" = {
      source = "${self}/dotfiles/common/configs/claude/agents/repo-creator-agent.md";
      force = true;
    };
    ".claude/agents/session-closer.md" = {
      source = "${self}/dotfiles/common/configs/claude/agents/session-closer.md";
      force = true;
    };
  };
}
