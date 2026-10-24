# Home scaffolding (xdg, home dirs derived from the shared options).
# User-agnostic, so it lives in the base foundation.
{
  flake.modules.homeManager.base =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    {
      xdg = {
        enable = true;
        localBinInPath = true;
      };

      home = {
        stateVersion = config.custom.stateVersions.home;
        # within a system, home-manager takes them from the account
        username = lib.mkIf config.custom.standalone config.custom.user.login;
        homeDirectory = lib.mkIf config.custom.standalone (
          if pkgs.stdenv.hostPlatform.isDarwin then
            "/Users/${config.custom.user.login}"
          else
            "/home/${config.custom.user.login}"
        );
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
