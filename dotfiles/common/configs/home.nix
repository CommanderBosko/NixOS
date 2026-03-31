{ pkgs, lib, self, ... }:

{
  home = {
    # Set home-manager state version
    stateVersion = "25.11"; # ← do NOT change this later — read the comment in home-manager release notes

    # Packages
    packages = with pkgs; [
      bash-language-server
      shfmt
      nodePackages.typescript-language-server
      nodePackages.prettier
      jdt-language-server
      pyright
      ruff
      lua-language-server
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

  # Customize helix
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

    languages.language = [
      {
        name = "nix";
        auto-format = true;
        formatter.command = lib.getExe pkgs.nixfmt;
        language-servers = [
          "nixd"
          "nil"
        ];
      }
      {
        name = "bash";
        auto-format = true;
        formatter = { command = lib.getExe pkgs.shfmt; args = ["-i" "2"]; };
        language-servers = [ "bash-language-server" ];
      }
      {
        name = "zsh";
        auto-format = true;
        formatter = { command = lib.getExe pkgs.shfmt; args = ["-i" "2"]; };
        language-servers = [ "bash-language-server" ];
      }
      {
        name = "javascript";
        auto-format = true;
        formatter = { command = lib.getExe pkgs.nodePackages.prettier; args = ["--parser" "typescript"]; };
        language-servers = [ "typescript-language-server" ];
      }
      {
        name = "java";
        auto-format = true;
        language-servers = [ "jdtls" ];
      }
      {
        name = "python";
        auto-format = true;
        formatter = { command = lib.getExe pkgs.ruff; args = ["format" "-"]; };
        language-servers = [ "pyright" ];
      }
      {
        name = "lua";
        auto-format = true;
        formatter = { command = lib.getExe pkgs.stylua; args = ["-"]; };
        language-servers = [ "lua-language-server" ];
      }
    ];

    themes = {
      autumn_night_transparent = {
        "inherits" = "autumn_night";
        "ui.background" = { };
      };
    };
  };
}
