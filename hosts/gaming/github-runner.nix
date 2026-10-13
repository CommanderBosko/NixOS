{ config, pkgs, ... }:

# GitHub Actions self-hosted runner for CommanderBosko/blueprint-smith's
# `harness` CI job (labels: self-hosted, linux, factorio). The job needs the
# Factorio 2.0.77 headless server, and factorio.com answers 403 to the
# download from GitHub-hosted runners, so it runs here against the copy
# already installed in bosko's cache.
#
# Isolation: blueprint-smith is a PUBLIC repo, and the workflow's "never for a
#            fork's PR" `if:` lives in the PR's own ci.yml, which a fork PR
#            can edit. Jobs are treated as untrusted code: they run as the
#            module's default DynamicUser (not bosko), and /home stays behind
#            a tmpfs except the one read-only server dir. Never set
#            ProtectHome = false: that exposes the sops age key and ~/.ssh to
#            every job.
# Server:    passed via $BPS_FACTORIO_SERVER. The module sets HOME to the
#            runner's work dir, so the harness's ~/.cache default never
#            resolves to /home/bosko. Each harness run writes to its own temp
#            dir, so the server dir can stay read-only.
# Token:     fine-grained PAT scoped to that repo ("Administration: read and
#            write"), one line with no trailing newline. The module copies it
#            as root before dropping privileges, so sops' default root-only
#            ownership is enough.
let
  factorioDir = "/home/bosko/.cache/blueprint-smith/factorio-headless-2.0.77";
in
{
  services.github-runners.blueprint-smith = {
    enable = true;
    url = "https://github.com/CommanderBosko/blueprint-smith";
    tokenFile = config.sops.secrets."github-runner-blueprint-smith".path;
    extraLabels = [ "factorio" ];
    extraPackages = [ pkgs.python314 ]; # the job builds a venv with python3
    extraEnvironment.BPS_FACTORIO_SERVER = "${factorioDir}/factorio/bin/x64/factorio";
    replace = true;
    serviceOverrides = {
      ProtectHome = "tmpfs";
      BindReadOnlyPaths = [ factorioDir ];
    };
  };

  sops.secrets."github-runner-blueprint-smith".sopsFile = ../../secrets/hosts/gaming.yaml;
}
