{ pkgs, src }:

# Mnemosyne memory provider for Hermes, built from the flake input instead of
# the pip-installed ~/.hermes/mnemosyne-venv. Two Python packages live in the
# one repo: the core (mnemosyne-memory) and the Hermes adapter under
# integrations/hermes (mnemosyne-hermes). Returns the plugin's files: they put
# the Python env on sys.path, then re-export the adapter, the same job as the
# wrapper the upstream installer generates.
let
  py = pkgs.python314Packages;

  mnemosyne-memory = py.buildPythonPackage {
    pname = "mnemosyne-memory";
    version = "4.0.0b5";
    inherit src;
    pyproject = true;
    build-system = [ py.setuptools ];
    dependencies = [
      py.pyyaml
      py.fastembed
      py.onnxruntime
      py.sqlite-vec
    ];
    # fastembed/onnxruntime in nixpkgs trail the upstream pins.
    pythonRelaxDeps = true;
    doCheck = false;
    pythonImportsCheck = [ "mnemosyne" ];
  };

  mnemosyne-hermes = py.buildPythonPackage {
    pname = "mnemosyne-hermes";
    version = "0.7.6";
    src = "${src}/integrations/hermes";
    pyproject = true;
    build-system = [ py.setuptools ];
    dependencies = [
      mnemosyne-memory
      py.pyyaml
    ];
    pythonRelaxDeps = true;
    doCheck = false;
    pythonImportsCheck = [ "mnemosyne_hermes" ];
  };

  env = pkgs.python314.withPackages (_: [ mnemosyne-hermes ]);
  sitePackages = "${env}/${pkgs.python314.sitePackages}";
in
{
  inherit env;
  # File contents for hermesHomeFiles."plugins/mnemosyne/<name>". Hermes finds a
  # memory provider by directory name (plugins/<memory.provider>), which rules
  # out extraPlugins: it installs as nix-managed-<name>.
  files = {
    "plugin.yaml" = builtins.readFile "${src}/integrations/hermes/src/mnemosyne_hermes/plugin.yaml";
    "__init__.py" = ''
      """Nix-built Mnemosyne Hermes plugin wrapper."""
      import sys

      sys.path.insert(0, "${sitePackages}")

      from mnemosyne_hermes import *  # noqa: F401,F403,E402
    '';
    "cli.py" = ''
      """Hermes CLI wrapper for the Nix-built Mnemosyne package."""
      import sys

      sys.path.insert(0, "${sitePackages}")

      from mnemosyne_hermes.cli import *  # noqa: F401,F403,E402
    '';
  };
}
