# User accounts across nixos base/user/children and darwin.
{
  flake.modules.nixos.base =
    { pkgs, lib, ... }:
    {
      users = {
        mutableUsers = false;
        defaultUserShell = pkgs.fish;
      };

      # Would replace the perl script that creates users and groups on activation,
      # but nixos-install creates no users with it: https://github.com/NixOS/nixpkgs/issues/408507
      services.userborn.enable = lib.mkDefault false;
    };

  flake.modules.nixos.user =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      users = {
        users.${config.custom.user.login} = {
          description = config.custom.user.name;
          home = "/home/${config.custom.user.login}";
          shell = pkgs.fish;
          uid = lib.mkDefault 1000;
          group = config.custom.user.login;
          extraGroups = [ "wheel" ];
          isNormalUser = true;
          openssh.authorizedKeys.keys = config.custom.user.sshKeys;
          subUidRanges = [
            {
              count = 65536;
              startUid = 100000;
            }
          ];
          subGidRanges = [
            {
              count = 65536;
              startGid = 100000;
            }
          ];
        };
        groups.${config.custom.user.login} = {
          gid = lib.mkDefault 1000;
        };
      };
    };

  flake.modules.nixos.children = {
    custom.user.login = "mirko";

    custom.children.users = {
      mila = {
        description = "Mila Lenz";
        uid = 1001;
      };
      levi = {
        description = "Levi Lenz";
        uid = 1002;
      };
    };
  };

  flake.modules.darwin.default =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      system.primaryUser = config.custom.user.login;
      users = {
        knownUsers = [ config.custom.user.login ];
        users.${config.custom.user.login} = {
          description = config.custom.user.name;
          home = "/Users/${config.custom.user.login}";
          shell = pkgs.fish;
          openssh.authorizedKeys.keys = config.custom.user.sshKeys;
          uid = lib.mkDefault 501;
          gid = lib.mkDefault 20;
          isHidden = false;
        };
      };
    };
}
