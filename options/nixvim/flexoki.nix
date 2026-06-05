{
  lib,
  ...
}:
lib.nixvim.plugins.mkNeovimPlugin {
  name = "flexoki";
  isColorscheme = true;

  maintainers = with lib.maintainers; [ mirkolenz ];
}
