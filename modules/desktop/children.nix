# Children's machines: German keyboard layout, Firefox with a Scratch shortcut,
# and a graphical terminal kept out of the Cosmic session but available to mirko.
{
  flake.modules.nixos.children =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.graphical.enable {
      services.xserver.xkb.layout = "de";

      programs.firefox.enable = true;

      # Keep the terminal out of the kids' Cosmic session but available to mirko.
      environment.cosmic.excludePackages = lib.mkIf (config.custom.features.graphical.desktopManager == "cosmic") (
        with pkgs;
        [
          cosmic-term
        ]
      );

      users.users.mirko.packages = lib.mkIf (config.custom.features.graphical.desktopManager == "cosmic") (
        with pkgs;
        [
          cosmic-term
        ]
      );

      environment.systemPackages = with pkgs; [
        (makeDesktopItem {
          name = "scratch";
          desktopName = "Scratch";
          exec = "firefox https://scratch.mit.edu";
          icon = "web-browser";
          categories = [ "Education" ];
        })
      ];
    };
}
