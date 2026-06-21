# Installer ISO base (formerly system/linux-installer/default.nix).
{
  flake.modules.nixos.installer =
    { config, pkgs, ... }:
    {
      services.openssh.enable = true;

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
