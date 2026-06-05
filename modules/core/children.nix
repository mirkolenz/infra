# Children (kiosk) systems: auto-upgrade, locale, locked-down Firefox, edu apps,
# and the nested "mirko" home-manager user.
{ config, lib, ... }:
let
  allowedSites = [
    "https://scratch.mit.edu/*"
    "https://*.scratch.mit.edu/*"
  ];
in
{
  flake.modules.nixos.children =
    { pkgs, ... }:
    {
      system.autoUpgrade.enable = true;

      i18n.defaultLocale = "de_DE.UTF-8";

      home-manager.users.mirko = {
        imports = [ config.flake.modules.homeManager.linux ];
        custom.user.login = lib.mkForce "mirko";
      };

      programs.firefox.policies = {
        WebsiteFilter = {
          Block = [ "<all_urls>" ];
          Exceptions = allowedSites;
        };

        BlockAboutConfig = true;
        DisableDeveloperTools = true;
        DisableFirefoxAccounts = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisablePrivateBrowsing = true;
        DisableProfileImport = true;
        DisableProfileRefresh = true;
        DisableSafeMode = true;
        DisableTelemetry = true;
        DontCheckDefaultBrowser = true;
        DownloadRestrictions = 3;
        HttpsOnlyMode = "enabled";
        NoDefaultBookmarks = true;
        OfferToSaveLogins = false;
        PasswordManagerEnabled = false;
        SearchSuggestEnabled = false;

        DisableSecurityBypass = {
          InvalidCertificate = true;
          SafeBrowsing = true;
        };

        ExtensionSettings."*" = {
          installation_mode = "blocked";
        };
      };

      environment.systemPackages = with pkgs; [
        gcompris
        tuxpaint
        tuxtype
      ];
    };
}
