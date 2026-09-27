# Boot defaults shared by all hosts, which enable their loader and set its stateful
# paths (`efiSysMountPoint`) explicitly.
{
  flake.modules.nixos.base = {
    boot.binfmt.preferStaticEmulators = true;

    boot.loader = {
      generic-extlinux-compatible.configurationLimit = 10;
      grub.configurationLimit = 10;
      systemd-boot.configurationLimit = 10;
      efi.canTouchEfiVariables = true;
    };
  };
}
