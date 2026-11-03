# Quick Share and AirDrop. See `pkgs/by-name/kait2en/airshare.nix` and
# `drop.nix`.
{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.custom.apple-t2.airshare;
      inherit (pkgs.kait2en) airshare drop;
      packages = [
        airshare
        drop
      ];
      helperPath = [
        pkgs.iproute2
        config.networking.networkmanager.package
      ];
    in
    {
      options.custom.apple-t2.airshare = {
        enable = lib.mkEnableOption "Quick Share and AirDrop through T2 AirShare";

        # Like `programs.localsend`, whose purpose is reaching other devices.
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to open the ports Quick Share and AirDrop receive on.";
        };
      };

      config = lib.mkIf cfg.enable {
        # Nautilus loads the context menu through nautilus-python.
        environment.systemPackages = [
          airshare
        ]
        ++ lib.optional config.services.desktopManager.gnome.enable pkgs.nautilus-python;

        hardware.bluetooth.enable = true;
        services.dbus.packages = packages;
        systemd.packages = packages;
        systemd.services.t2-drop.path = helperPath;
        systemd.services.t2-quickshare-hotspot.path = helperPath ++ [ pkgs.iw ];

        # `t2-drop` owns the AWDL interface.
        networking.networkmanager.unmanaged = [ "interface-name:awdl*" ];

        networking.firewall = lib.mkIf cfg.openFirewall {
          # Quick Share in a shared network and its own mDNS responder.
          allowedTCPPorts = [ airshare.port ];
          allowedUDPPorts = [ 5353 ];
          interfaces.awdl0.allowedTCPPorts = [ drop.port ];
          # The one-off Quick Share hotspot, see the README.
          trustedInterfaces = [ "t2qs0" ];
        };
      };
    };
}
