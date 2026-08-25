# @yawlabs/tailscale-mcp isn't in nixpkgs (checked via mcp-nixos search,
# 2026-08-25) — this is a from-scratch package, unlike mcp-nixos which is
# just referenced straight from nixpkgs. Chosen over ~6 other unofficial
# Tailscale MCP servers for MIT licensing, 700+ unit tests, and the widest
# read/write API coverage (devices, DNS, ACL/policy, routes, keys, users).
#
# The npm tree ships no runtime `dependencies` — esbuild bundles everything
# into dist/index.js at build time — so the default buildNpmPackage install
# phase (which just stages the published `files` and wraps the `bin` entry
# with node) needs no further pruning.
#
# The server also shells out to the local `tailscale` CLI for a handful of
# tools (its own bin/tailscale-mcp.mjs launcher comment says as much), so
# `tailscale` is put on PATH via wrapProgram.
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  tailscale,
}:

buildNpmPackage rec {
  pname = "tailscale-mcp";
  version = "0.17.1";

  src = fetchFromGitHub {
    owner = "YawLabs";
    repo = "tailscale-mcp";
    tag = "v${version}";
    hash = "sha256-TGMtSk/rdVOGvlb2LkQ/csYqTDLTV0ahTd30LRsWAts=";
  };

  npmDepsHash = "sha256-j7l4cYLf+Ha8ZPdVFIGO76WVs4GJI4IdhgUmAUPkC/M=";

  nativeBuildInputs = [ makeWrapper ];

  postFixup = ''
    wrapProgram $out/bin/tailscale-mcp \
      --prefix PATH : ${lib.makeBinPath [ tailscale ]}
  '';

  meta = {
    description = "MCP server for managing a Tailscale tailnet from AI assistants";
    homepage = "https://github.com/YawLabs/tailscale-mcp";
    license = lib.licenses.mit;
    mainProgram = "tailscale-mcp";
    platforms = lib.platforms.unix;
  };
}
