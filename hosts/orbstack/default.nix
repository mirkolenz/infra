{
  modulesPath,
  user,
  lib',
  lib,
  ...
}:
{
  # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/lxc-instance-common.nix
  imports = lib'.flocken.getModules ./. ++ [
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];

  # lxc imports installer/cd-dvd/channel.nix
  system.installer.channel.enable = false;

  custom.nix.settings.trusted-users = [ user.login ];

  home-manager.users.${user.login} = {
    programs.fish.functions.fish_greeting.body = lib.mkForce "";
  };
}
