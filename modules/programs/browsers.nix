# The browsers used on graphical Linux hosts.
#
# All three go through their home-manager module rather than a plain
# home.packages entry, because those modules are what install the native
# messaging hosts that the Vicinae browser extension needs in order to reach
# the launcher. The hosts are a no-op while the browser itself is disabled,
# since the whole config block of both modules is gated on `enable`.
{
  flake.modules.homeManager.linux =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.graphical.enable {
      # programs.vicinae contributes its messaging host to firefox and
      # google-chrome on its own (enableFirefoxIntegration and
      # enableChromeIntegration), but not to Vivaldi.
      programs.vivaldi = {
        enable = true;
        nativeMessagingHosts = [ config.programs.vicinae.package ];
      };

      programs.firefox.enable = true;
      programs.google-chrome.enable = true;
    };
}
