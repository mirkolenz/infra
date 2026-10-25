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
      locale = lib.head (lib.splitString "_" config.i18n.defaultLocale);

      # Policies in the wrapper, unlike /etc/firefox/policies, spare the primary user's Firefox.
      firefox = pkgs.firefox.override {
        extraPolicies = {
          # The build of nixpkgs is cached but English, so Firefox fetches the language pack
          # of its exact version and reinstalls it once the URL changes with the version.
          RequestedLocales = [ locale ];
          ExtensionSettings = {
            "*".installation_mode = "blocked";
            "langpack-${locale}@firefox.mozilla.org" = {
              installation_mode = "force_installed";
              install_url = "https://releases.mozilla.org/pub/firefox/releases/${pkgs.firefox.version}/linux-x86_64/xpi/${locale}.xpi";
            };
            # the language pack lacks spell checking
            "de-DE@dictionaries.addons.mozilla.org" = {
              installation_mode = "force_installed";
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/dictionary-german/latest.xpi";
            };
          };

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
