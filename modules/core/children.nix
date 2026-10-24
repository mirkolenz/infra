# Children's machines: auto-upgrade, locale, and a Firefox limited to their websites.
{
  flake.modules.nixos.children =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Policies in the wrapper, unlike /etc/firefox/policies, spare the primary user's Firefox.
      firefox = pkgs.firefox.override {
        extraPolicies = {
          WebsiteFilter = {
            Block = [ "<all_urls>" ];
            Exceptions = lib.concatMap (site: site.allow) (lib.attrValues config.custom.websites);
          };

          BlockAboutConfig = true;
          # also screens what allowed pages load from elsewhere
          DNSOverHTTPS = {
            Enabled = true;
            ProviderURL = "https://family.cloudflare-dns.com/dns-query";
            Fallback = false;
            Locked = true;
          };
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
      };
    in
    {
      system.autoUpgrade.enable = true;

      i18n.defaultLocale = "de_DE.UTF-8";

      custom.websites = {
        scratch = {
          title = "Scratch";
          url = "https://scratch.mit.edu";
          # includes scratch.mit.edu
          allow = [ "https://*.scratch.mit.edu/*" ];
          categories = [ "Education" ];
          icon = "edu.mit.Scratch";
        };
        antolin = {
          title = "Antolin";
          url = "https://antolin.westermann.de";
          categories = [ "Education" ];
          icon = "accessories-ebook-reader";
        };
      };

      # the copied binaries of the wrapper, the unwrapped Firefox without policies stays offline
      custom.children.online = [ "${firefox}/lib/firefox/firefox{,-bin}" ];

      environment.systemPackages = [ firefox ];
    };
}
