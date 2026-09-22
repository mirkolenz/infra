# Installer ISO base (formerly system/linux-installer/default.nix).
{
  flake.modules.nixos.installer =
    {
      config,
      lib,
      modulesPath,
      pkgs,
      ...
    }:
    {
      # Declares `system.installer.channel.enable`: the bucket imports no
      # installation-CD profile, so the option does not otherwise exist.
      imports = [ "${modulesPath}/installer/cd-dvd/channel.nix" ];

      # `profiles/installation-device.nix`, pulled in by the iso-installer image,
      # trims the mbrola voices with an overlay, which the shared read-only package
      # set rejects. speechd is off here, so the overlay changes nothing.
      nixpkgs.overlays = lib.mkForce config.nixpkgs.pkgs.overlays;

      services.openssh.enable = true;

      # `profiles/base.nix` enables ZFS by default, which forces a from-source
      # build of the ZFS kernel module against the patched T2 kernel.
      boot.supportedFilesystems.zfs = false;

      users = {
        defaultUserShell = pkgs.fish;

        users.root = {
          openssh.authorizedKeys.keys = config.custom.user.sshKeys;
        };
      };

      environment.systemPackages = with pkgs; [
        zellij
      ];

      programs = {
        git.enable = true;
        fish.enable = true;
        neovim = {
          enable = true;
          viAlias = true;
          vimAlias = true;
        };
      };

      nix = {
        channel.enable = false;
        settings = {
          accept-flake-config = true;
          use-xdg-base-directories = true;
        };
      };

      system.installer.channel.enable = false;
    };
}
