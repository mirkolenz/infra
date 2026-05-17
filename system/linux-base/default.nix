{
  config,
  lib',
  stateVersions,
  lib,
  pkgs,
  ...
}:
{
  imports = lib'.flocken.getModules ./.;

  system.stateVersion = stateVersions.linux;

  services.printing.enable = false;

  # todo: fails on raspi (mkswap-swapfile-start)
  # https://github.com/NixOS/nixpkgs/pull/470270
  systemd.enableStrictShellChecks = false;

  documentation = {
    nixos.enable = false;
    # this is slow
    man.cache.enable = false;
  };

  boot.loader = {
    generic-extlinux-compatible.configurationLimit = 10;
    grub.configurationLimit = 10;
    systemd-boot.configurationLimit = 10;
  };
  boot.binfmt.preferStaticEmulators = true;

  hardware.enableAllFirmware = true;

  zramSwap = {
    enable = true;
    memoryPercent = 100;
    memoryMax = 8 * 1024 * 1024 * 1024;
  };

  environment.variables.BROWSER = lib.mkIf (!config.custom.features.withDisplay) "echo";

  environment.systemPackages = with pkgs; [
    pciutils
  ];
}
