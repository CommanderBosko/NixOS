# Symlinks from the repo-managed Claude sources (dotfiles/bosko/claude/) into
# ~/.claude. Skills and agents are discovered from the directory listing, so a
# new skill or agent needs no wiring here — just `git add` it (the flake only
# sees tracked files) and rebuild. claude/knowledge/ is deliberately NOT linked:
# it has to stay a writable working-tree dir (see its README).
{ self, lib, ... }:

let
  src = "${self}/dotfiles/bosko/claude";

  # Entries of `dir` of the given readDir type ("directory" / "regular").
  entriesOf = type: dir: lib.filterAttrs (_: t: t == type) (builtins.readDir dir);

  # Every subdirectory of skills/ is one recursive dir symlink, so SKILL.md and
  # any scripts/, assets/ or references/ ride along, and files added later need
  # no further wiring. lib/ (no SKILL.md) is the shared helper scripts several
  # skills call — same mechanics.
  skills = lib.mapAttrs' (
    name: _:
    lib.nameValuePair ".claude/skills/${name}" {
      source = "${src}/skills/${name}";
      recursive = true;
      force = true;
    }
  ) (entriesOf "directory" "${src}/skills");

  # Custom subagents (.claude/agents/*.md) are auto-discovered by the Agent
  # tool; the symlink is all the registration they need. Single files, so no
  # `recursive`.
  agents = lib.mapAttrs' (
    name: _:
    lib.nameValuePair ".claude/agents/${name}" {
      source = "${src}/agents/${name}";
      force = true;
    }
  ) (lib.filterAttrs (name: _: lib.hasSuffix ".md" name) (entriesOf "regular" "${src}/agents"));
in
{
  home.file = {
    # Global standing instructions loaded in every project (currently: pair
    # /init with the claude-rules skill). Plain file, not a skill.
    ".claude/CLAUDE.md" = {
      source = "${src}/CLAUDE.md";
      force = true;
    };
    # `manager` (agents/manager.md) decides tasks the way this user would, per
    # this profile of their decision-making style, mined from Claude Code
    # transcripts across every project (skills/refresh-manager-profile keeps it
    # current). Plain top-level file, not a skill — same pattern as CLAUDE.md.
    ".claude/manager-profile.md" = {
      source = "${src}/manager-profile.md";
      force = true;
    };
  }
  // skills
  // agents;
}
