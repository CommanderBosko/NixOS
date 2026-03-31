{
  pkgs,
  lib,
  self,
  ...
}:

{
  home = {
    # Set home-manager state version
    stateVersion = "25.11"; # ← do NOT change this later — read the comment in home-manager release notes

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

    # Copy over dotfiles

    # Kate
    file.".config/katerc" = {
      source = "${self}/dotfiles/common/configs/katerc";
      force = true;
    };

    # Kitty
    file.".config/kitty/kitty.conf" = {
      source = "${self}/dotfiles/common/configs/kitty.conf";
      force = true;
    };

    # Starship
    file.".config/starship.toml" = {
      source = "${self}/dotfiles/common/configs/starship.toml";
      force = true;
    };
  };

  # Customize programs
  programs = {
    # Helix
    helix = {
      enable = true;
      settings = {
        theme = "autumn_night_transparent";
        editor.cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };
      };

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

      themes = {
        autumn_night_transparent = {
          "inherits" = "autumn_night";
          "ui.background" = { };
        };
      };
    };
  };
}
