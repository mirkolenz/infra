{ lib, ... }:
lib.nixvim.plugins.mkNeovimPlugin {
  name = "multiple-cursors";
  maintainers = with lib.maintainers; [ mirkolenz ];
}
