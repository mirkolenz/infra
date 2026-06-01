{
  lib,
  ...
}:
lib.nixvim.plugins.mkNeovimPlugin {
  name = "direnv-nvim";
  moduleName = "direnv";
  package = "direnv-nvim";

  maintainers = with lib.maintainers; [ mirkolenz ];

  settingsExample = {
    autoload_direnv = true;
    keybindings = false;
  };
}
