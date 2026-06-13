# Knowledge base — advisory board

Shared, version-controlled store for the `new-team-member`, `team-meeting`, and
`team-member-ingest` Claude skills. Because the skills are installed globally
(symlinked into `~/.claude/skills/`) and read/write **this absolute path**
(`/home/bosko/NixOS/dotfiles/bosko/claude/knowledge/`), the profiles are
available from any project, not just whichever one Claude happens to run in.

These are plain working-tree files — **not** wired through `bosko-claude.nix`
`home.file`, because those land read-only in `/nix/store` and the skills need to
write here.

## Layout

```
knowledge/
├── team-member.md            # YOUR own profile (built by new-team-member)
├── raw/                      # gitignored — raw pasted source material
│   └── <person-slug>/
│       └── YYYY-MM-DD-<title>.md
└── <person-slug>/
    └── team-member.md        # synthesized profile of an advisor
```

- `raw/` is **gitignored** (see repo `.gitignore`): transcripts/articles can be
  bulky and copyrighted, so they stay local.
- The synthesized `team-member.md` profiles **are** committed (private repo), so
  they're version-controlled and global.
