# FamDash is a small Express app (single runtime dependency, no native modules,
# no build step) kept in a private repo, so `src` is passed in by the caller
# (a flake input in production) instead of being fetched here.
#
# Only what the server needs at runtime is installed under $out/lib/famdash,
# not the repo's docs and tooling, and the default npm install hook is skipped
# (it would stage the whole repo under lib/node_modules/famdash-server). The
# app is started through a node wrapper, so there is no npm scripts layer.
{
  lib,
  buildNpmPackage,
  makeWrapper,
  nodejs,
  src,
}:

let
  # Reading package.json out of `src` is not import-from-derivation as long as
  # `src` is already a store path, which a flake input always is.
  packageJson = builtins.fromJSON (builtins.readFile "${src}/package.json");
in
buildNpmPackage {
  pname = "famdash";
  inherit (packageJson) version;
  inherit src;

  npmDepsHash = "sha256-2c9AbbAGSAYrWOVCppJ6gpiXyMOuis5EBKWiozKTvyA=";

  # Plain JavaScript: nothing to compile, and the repo has no `build` script.
  dontNpmBuild = true;
  # Production dependencies only; keeps dev tooling out of the closure.
  npmInstallFlags = [ "--omit=dev" ];

  # server.js hardcodes its database next to the script, which would be the
  # read-only Nix store. Let the service point it at a state directory
  # (FAMDASH_DB=/var/lib/famdash/db.json) and keep the old path as the default.
  postPatch = ''
    substituteInPlace server.js \
      --replace-fail "const DB_FILE = path.join(__dirname, 'db.json');" \
                     "const DB_FILE = process.env.FAMDASH_DB || path.join(__dirname, 'db.json');"
  '';

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/famdash
    cp -r server.js package.json public node_modules $out/lib/famdash/

    # PORT is hardcoded to 3000 in server.js.
    makeWrapper ${lib.getExe nodejs} $out/bin/famdash \
      --add-flags $out/lib/famdash/server.js \
      --set NODE_ENV production

    runHook postInstall
  '';

  meta = {
    description = "FamDash family dashboard (chores, meals, shopping, notes, recipes)";
    mainProgram = "famdash";
    platforms = lib.platforms.linux;
  };
}
