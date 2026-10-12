# The browsers used on graphical Linux hosts, with Firefox as the default.
#
# Both go through their home-manager module rather than a plain
# home.packages entry, because those modules are what install the native
# messaging hosts that the Vicinae browser extension needs in order to reach
# the launcher. programs.vicinae contributes its host to both on its own,
# via enableFirefoxIntegration and enableChromeIntegration.
{
  flake.modules.homeManager.linux =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.graphical.enable {
      programs.firefox.enable = true;
      programs.google-chrome.enable = true;

      xdg.mimeApps = {
        enable = true;
        defaultApplications = lib.genAttrs [
          "text/html"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
        ] (_: "firefox.desktop");
      };

      # desktop environments rewrite mimeapps.list when defaults change in their settings
      xdg.configFile."mimeapps.list".force = true;
    };
}
