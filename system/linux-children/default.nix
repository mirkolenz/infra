{
  self,
  lib,
  lib',
  user,
  ...
}:
{
  imports = lib'.flocken.getModules ./.;

  system.autoUpgrade.enable = true;

  i18n.defaultLocale = "de_DE.UTF-8";

  home-manager.users.mirko = {
    imports = [ self.homeModules.linux ];
    _module.args.user = lib.mkForce (user // { login = "mirko"; });
  };
}
