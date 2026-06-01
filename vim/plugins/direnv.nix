{
  lib,
  pkgs,
  ...
}:
{
  plugins.direnv-nvim = {
    enable = true;
    settings = {
      bin = lib.getExe pkgs.direnv;
      autoload_direnv = true;
      keybindings = false;
      statusline = {
        enabled = true;
        icon = "󱚟";
      };
      notifications = {
        level = lib.nixvim.mkRaw "vim.log.levels.INFO";
        silent_autoload = true;
      };
    };
  };
}
