# General desktop defaults: NetworkManager, the default keyboard layout, and
# personal-workstation conveniences (Nix trust, nix-ld) for interactive machines.
{
  flake.modules.nixos.base =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.withDisplay {
      # there is an issue with wpa_supplicant and broadcom-wl (used in Macs)
      networking.networkmanager = {
        enable = true;
        wifi.backend = "iwd";
      };

      nix.settings.trusted-users = [ "@wheel" ];

      programs.nix-ld.enable = true;
    };

  flake.modules.nixos.default =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.withDisplay {
      services.xserver.xkb.layout = "us";

      users.users.${config.custom.user.login}.extraGroups = [ "networkmanager" ];
    };
}
