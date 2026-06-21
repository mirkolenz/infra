# Home scaffolding (xdg, home dirs derived from the shared options).
# User-agnostic, so it lives in the base foundation.
{
  flake.modules.homeManager.base =
    {
      pkgs,
      config,
      ...
    }:
    {
      xdg = {
        enable = true;
        localBinInPath = false;
      };

      home = {
        stateVersion = config.custom.stateVersions.home;
        username = config.custom.user.login;
        homeDirectory =
          if pkgs.stdenv.isDarwin then
            "/Users/${config.custom.user.login}"
          else
            "/home/${config.custom.user.login}";
        file = {
          ".hushlogin".text = "";
        };
      };

      manual = {
        html.enable = false;
        json.enable = false;
        manpages.enable = false;
      };
    };
}
