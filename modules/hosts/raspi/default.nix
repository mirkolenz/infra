{ config, ... }:
let
  inherit (config.flake) modules;
in
{
  configurations.nixos.raspi = {
    system = "aarch64-linux";
    module = {
      imports = [
        modules.nixos.default
        modules.nixos.low-memory
      ];

      custom.features.unattended.enable = true;

      services.tailscale = {
        extraSetFlags = [
          "--advertise-exit-node"
        ];
        useRoutingFeatures = "server";
      };
    };
  };
}
