{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      chromium = lib.getExe' pkgs.playwright-headless "chrome-headless-shell";
    in
    lib.mkIf config.programs.agents.enable {
      home.packages = [ pkgs.playwright-headless ];

      programs.agents.sandbox.environment.set = {
        PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-headless}/browsers";
        PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
        PUPPETEER_EXECUTABLE_PATH = chromium;
        PUPPETEER_SKIP_DOWNLOAD = "1";
        # chrome-launcher, used by lighthouse among others
        CHROME_PATH = chromium;
      };

      # Chromium spreads over processes, which meet at a Mach service of the browser named after its pid.
      programs.nono.profiles.agents.unsafe_macos_seatbelt_rules =
        lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
          [
            ''(allow mach-register mach-lookup (global-name-regex #"^org\.chromium\.Chromium\.MachPortRendezvousServer\.[0-9]+$"))''
          ];
    };
}
