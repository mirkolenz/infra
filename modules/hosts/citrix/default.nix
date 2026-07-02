# NixOS guest for a Citrix Hypervisor / XCP-ng (Xen) pool. Deploys like any other
# host (nixos-rebuild switch --flake .#citrix) and exports a VHD image
# (system.build.image-vhd, see image.nix) for the hypervisor admin to import.
#
# Import the VM as UEFI with Secure Boot disabled: XenCenter defaults to the most
# secure boot mode, but systemd-boot is unsigned so Secure Boot refuses to load it.
# - https://docs.xenserver.com/en-us/xenserver/8/vms/linux.html
# - https://docs.xcp-ng.org/vms/
# - https://xcp-ng.org/blog/2021/01/28/guest-uefi-secure-boot/amp/
{ config, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.citrix.module =
    { modulesPath, ... }:
    {
      imports = [
        nixos.default
        # Cloud-style image: an ext4 root + ESP labelled by disk-image.nix, with
        # boot.growPartition and root autoResize so the filesystem expands to
        # fill whatever disk Citrix assigns. Also exposes system.build.image and
        # enables systemd-boot (image.efiSupport defaults to true).
        (modulesPath + "/virtualisation/disk-image.nix")
      ];
      nixpkgs.hostPlatform = "x86_64-linux";

      custom.features.withAlwaysOn = true;

      # Compact intermediate; diskSize defaults to "auto" so the artifact stays
      # small and the root grows on first boot. Converted to a fixed VHD by
      # system.build.image-vhd (see image.nix).
      image = {
        format = "qcow2";
        baseName = "citrix";
      };

      boot.loader.efi.canTouchEfiVariables = true;

      # XenServer VM Tools: report the VM's IP and OS to XenCenter and allow clean
      # shutdown, reboot and suspend from the hypervisor. Mounts xenfs on
      # /proc/xen. The PV drivers themselves are already in the kernel.
      services.xe-guest-utilities.enable = true;
    };
}
