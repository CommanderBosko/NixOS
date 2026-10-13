# Bosko-only kitty drop-in, layered onto the shared kitty.conf
# (dotfiles/common/configs/kitty.conf) via its `globinclude kitty.d/*.conf`.
{
  home.file.".config/kitty/kitty.d/boss.conf".source = ./kitty-boss.conf;
}
