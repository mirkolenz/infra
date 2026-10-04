# Boot defaults shared by all hosts, which enable their loader and set its stateful
# paths (`efiSysMountPoint`, `pkiBundle`) explicitly. See the README for Secure Boot.
{
  flake.modules.nixos.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.boot.lanzaboote;
    in
    {
      boot.binfmt.preferStaticEmulators = true;

      boot.loader = {
        generic-extlinux-compatible.configurationLimit = lib.mkDefault 10;
        grub.configurationLimit = lib.mkDefault 10;
        systemd-boot.configurationLimit = lib.mkDefault 10;
        efi.canTouchEfiVariables = true;
      };

      boot.lanzaboote = {
        # https://nix-community.github.io/lanzaboote/explanation/automatic-provisioning.html
        autoGenerateKeys.enable = lib.mkDefault true;
        autoEnrollKeys = {
          enable = lib.mkDefault true;
          autoReboot = lib.mkDefault true;
        };
        # https://nix-community.github.io/lanzaboote/how-to-guides/enable-measured-boot.html
        measuredBoot.pcrs = lib.mkDefault [
          0
          4
          7
        ];
        # systemd-pcrlock allows 8 variants per PCR, 2 boot loaders x 4 generations.
        configurationLimit = lib.mkIf cfg.measuredBoot.enable (lib.mkDefault 4);
      };

      environment.systemPackages = lib.mkIf cfg.enable [ pkgs.sbctl ];
    };
}
