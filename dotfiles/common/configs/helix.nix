{ lib, pkgs, ... }:
{
  home = {
    # Packages
    packages = with pkgs; [
      bash-language-server
      gofumpt
      gopls
      jdt-language-server
      lua-language-server
      marksman
      prettier
      pyright
      ruff
      rust-analyzer
      rustfmt
      shfmt
      stylua
      taplo
      terraform-ls
      typescript-language-server
      vscode-langservers-extracted
      yaml-language-server
    ];
  };

  # Settings
  programs.helix = {
    enable = true;
    settings = {
      theme = "autumn_night_transparent";
      editor.cursor-shape = {
        normal = "block";
        insert = "bar";
        select = "underline";
      };
    };

    # Themes
    themes = {
      autumn_night_transparent = {
        "inherits" = "autumn_night";
        "ui.background" = { };
      };
    };

    # Languages and language servers. Each entry merges by `name` into helix's
    # built-in language, so unset keys (scope, ...) are inherited; list values
    # (file-types, language-servers) replace the built-in list outright, dropping
    # every built-in entry not repeated here.
    languages.language = [
      {
        name = "bash";
        file-types = [
          "sh"
          "bash"
        ];
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.shfmt;
          args = [
            "-i"
            "2"
          ];
        };
        language-servers = [ "bash-language-server" ];
      }
      {
        name = "c";
        auto-format = false;
        formatter = {
          command = "${pkgs.clang-tools}/bin/clang-format";
        };
        language-servers = [ "clangd" ];
      }
      {
        name = "cpp";
        file-types = [
          "cpp"
          "cc"
          "cxx"
          "h"
          "hh"
          "hpp"
          "hxx"
        ];
        auto-format = false;
        formatter = {
          command = "${pkgs.clang-tools}/bin/clang-format";
        };
        language-servers = [ "clangd" ];
      }
      {
        name = "css";
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.prettier;
          args = [
            "--parser"
            "css"
          ];
        };
        language-servers = [ "vscode-css-language-server" ];
      }
      {
        name = "go";
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.gofumpt;
        };
        language-servers = [ "gopls" ];
      }
      {
        # No formatter: terraform-ls has no `fmt` subcommand and terraform
        # itself isn't installed.
        name = "hcl";
        file-types = [
          "tf"
          "hcl"
        ];
        auto-format = false;
        language-servers = [ "terraform-ls" ];
      }
      {
        name = "html";
        file-types = [ "html" ];
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.prettier;
          args = [
            "--parser"
            "html"
          ];
        };
        language-servers = [ "vscode-html-language-server" ];
      }
      {
        name = "java";
        file-types = [ "java" ];
        auto-format = false;
        language-servers = [ "jdtls" ];
      }
      {
        name = "javascript";
        file-types = [
          "js"
          "mjs"
          "cjs"
        ];
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.prettier;
          args = [
            "--parser"
            "typescript"
          ];
        };
        language-servers = [ "typescript-language-server" ];
      }
      {
        name = "json";
        file-types = [
          "json"
          "jsonc"
        ];
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.prettier;
          args = [
            "--parser"
            "json"
          ];
        };
        language-servers = [ "vscode-json-language-server" ];
      }
      {
        name = "lua";
        file-types = [ "lua" ];
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.stylua;
          args = [ "-" ];
        };
        language-servers = [ "lua-language-server" ];
      }
      {
        name = "markdown";
        file-types = [
          "md"
          "markdown"
        ];
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.prettier;
          args = [
            "--parser"
            "markdown"
          ];
        };
        language-servers = [ "marksman" ];
      }
      {
        name = "nix";
        auto-format = false;
        formatter.command = lib.getExe pkgs.nixfmt;
        language-servers = [
          "nixd"
          "nil"
        ];
      }
      {
        name = "python";
        file-types = [ "py" ];
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.ruff;
          args = [
            "format"
            "-"
          ];
        };
        language-servers = [ "pyright" ];
      }
      {
        name = "rust";
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.rustfmt;
        };
        language-servers = [ "rust-analyzer" ];
      }
      {
        name = "toml";
        file-types = [ "toml" ];
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.taplo;
          args = [
            "fmt"
            "-"
          ];
        };
        language-servers = [ "taplo" ];
      }
      {
        name = "yaml";
        file-types = [
          "yaml"
          "yml"
        ];
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.prettier;
          args = [
            "--parser"
            "yaml"
          ];
        };
        language-servers = [ "yaml-language-server" ];
      }
      {
        name = "zsh";
        scope = "source.zsh";
        file-types = [ "zsh" ];
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.shfmt;
          args = [
            "-i"
            "2"
          ];
        };
        language-servers = [ "bash-language-server" ];
      }
    ];
  };
}
