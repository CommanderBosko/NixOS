{ lib, pkgs, ... }:
{
  home = {
    # Packages
    packages = with pkgs; [
      bash-language-server
      clang-tools
      gofumpt
      gopls
      jdt-language-server
      lua-language-server
      marksman
      prettier
      typescript-language-server
      pyright
      rust-analyzer
      rustfmt
      ruff
      shfmt
      stylua
      taplo
      terraform-ls
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

    # Languages and language servers
    languages.language = [
      {
        name = "bash";
        scope = "source.bash";
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
        scope = "source.c";
        file-types = [ "c" ];
        auto-format = false;
        formatter = {
          command = "${pkgs.clang-tools}/bin/clang-format";
        };
        language-servers = [ "clangd" ];
      }
      {
        name = "cpp";
        scope = "source.cpp";
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
        scope = "source.css";
        file-types = [ "css" ];
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
        scope = "source.go";
        file-types = [ "go" ];
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.gofumpt;
        };
        language-servers = [ "gopls" ];
      }
      {
        name = "hcl";
        scope = "source.hcl";
        file-types = [
          "tf"
          "hcl"
        ];
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.terraform-ls;
          args = [
            "fmt"
            "-"
          ];
        };
        language-servers = [ "terraform-ls" ];
      }
      {
        name = "html";
        scope = "text.html.basic";
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
        scope = "source.java";
        file-types = [ "java" ];
        auto-format = false;
        language-servers = [ "jdtls" ];
      }
      {
        name = "javascript";
        scope = "source.js";
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
        scope = "source.json";
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
        scope = "source.lua";
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
        scope = "source.md";
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
        scope = "source.nix";
        file-types = [ "nix" ];
        auto-format = false;
        formatter.command = lib.getExe pkgs.nixfmt;
        language-servers = [
          "nixd"
          "nil"
        ];
      }
      {
        name = "python";
        scope = "source.python";
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
        scope = "source.rust";
        file-types = [ "rs" ];
        auto-format = false;
        formatter = {
          command = lib.getExe pkgs.rustfmt;
        };
        language-servers = [ "rust-analyzer" ];
      }
      {
        name = "toml";
        scope = "source.toml";
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
        scope = "source.yaml";
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
