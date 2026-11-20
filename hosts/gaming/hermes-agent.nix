{ ... }:

# Gaming-only Hermes additions on top of modules/hermes-agent.nix (every desktop):
# skills for services only this host runs. They merge into the shared
# hermesHomeFiles and are rewritten on every rebuild, so Hermes can't drift them.
{
  home-manager.users.bosko.services.hermes-agent.hermesHomeFiles = {
    # How to use the user's Proton mail (hosts/gaming/proton-mail.nix).
    "skills/email/proton-mail/SKILL.md" = ./hermes-proton-mail-skill.md;
    # Read-only view of the monitoring stack (hosts/gaming/monitoring.nix).
    "skills/monitoring/homelab-monitoring/SKILL.md" = ./hermes-monitoring-skill.md;
  };
}
