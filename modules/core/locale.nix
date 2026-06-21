# Locale: the en_US.UTF-8 locale shared across NixOS, nix-darwin and
# home-manager, mirroring the pager module. NixOS additionally pins
# i18n.defaultLocale.
let
  locale = "en_US.UTF-8";
  variables = {
    LANG = locale;
    LC_ALL = locale;
  };
  system = {
    environment.variables = variables;
  };
in
{
  flake.modules.nixos.default = {
    imports = [ system ];
    i18n.defaultLocale = locale;
  };
  flake.modules.darwin.default = system;
  flake.modules.homeManager.base = {
    home.sessionVariables = variables;
  };
}
