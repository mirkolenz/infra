{
  pkgs,
  config,
  lib,
  user,
  ...
}:
{
  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/virtualisation/libvirtd.nix
  virtualisation.libvirtd = {
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      vhostUserPackages = [ pkgs.virtiofsd ];
      swtpm.enable = true;
    };
  };

  # https://wiki.nixos.org/wiki/Networking#Virtualization
  networking.firewall.interfaces."virbr*" = lib.mkIf config.virtualisation.libvirtd.enable {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [
      53 # dns
      67 # dhcp
    ];
  };

  users.users.${user.login}.extraGroups = lib.mkIf config.virtualisation.libvirtd.enable [
    "libvirtd"
  ];

  programs.virt-manager.enable = lib.mkDefault config.custom.features.withDisplay;

  environment.systemPackages = lib.mkIf config.custom.features.withDisplay [
    pkgs.virt-viewer
  ];

  environment.etc = lib.mkIf config.virtualisation.libvirtd.enable {
    "nix-libvirtd/images/virtio-win.iso".source = pkgs.virtio-win.src;
  };
}
