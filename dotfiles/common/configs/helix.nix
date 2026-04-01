{ lib, pkgs, ... }:

{
  home = {
    # Packages
    packages = with pkgs; [
      bash-language-server
      jdt-language-server
      lua-language-server
      nodePackages.prettier
      nodePackages.typescript-language-server
      pyright
      ruff
      shfmt
      stylua
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
        auto-format = true;
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
        name = "java";
        scope = "source.java";
        file-types = [ "java" ];
        auto-format = true;
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
        auto-format = true;
        formatter = {
          command = lib.getExe pkgs.nodePackages.prettier;
          args = [
            "--parser"
            "typescript"
          ];
        };
        language-servers = [ "typescript-language-server" ];
      }
      {
        name = "lua";
        scope = "source.lua";
        file-types = [ "lua" ];
        auto-format = true;
        formatter = {
          command = lib.getExe pkgs.stylua;
          args = [ "-" ];
        };
        language-servers = [ "lua-language-server" ];
      }
      {
        name = "nix";
        scope = "source.nix";
        file-types = [ "nix" ];
        auto-format = true;
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
        auto-format = true;
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
        name = "zsh";
        scope = "source.zsh";
        file-types = [ "zsh" ];
        auto-format = true;
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
