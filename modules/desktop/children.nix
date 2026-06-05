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
    lib.mkIf config.custom.features.withDisplay {
      services.xserver.xkb.layout = "de";

      programs.firefox.enable = true;

      environment.cosmic.excludePackages = with pkgs; [
        cosmic-term
      ];

      users.users.mirko.packages = with pkgs; [
        cosmic-term
      ];

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
