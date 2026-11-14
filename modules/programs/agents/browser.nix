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

      # Prints the body even on HTTP errors, but keeps the exit code of curl.
      # The arguments go before the URL, so they can override the defaults.
      custom.commands.webget.text = /* bash */ ''
        # @describe Fetch a URL as a browser would, converting HTML pages to Markdown
        # @arg url!         URL to fetch
        # @arg curl-args~   Further arguments of curl

        body="$(mktemp -t webget.XXXXXX)"
        trap 'rm -f -- "$body"' EXIT
        status=0

        meta="$(${lib.getExe pkgs.curl-impersonate} --impersonate chrome150 --compressed --location \
          --silent --show-error --fail-with-body --output "$body" --write-out '%{url_effective} %{content_type}' \
          "''${argc_curl_args[@]}" --url "$argc_url")" || status=$?
        read -r final type <<<"$meta"

        if [[ ''${type,,} == *html* ]]; then
          ${lib.getExe pkgs.html2markdown} --plugin-table --plugin-strikethrough \
            --exclude-selector 'img[src^="data:"]' --domain "$final" --input "$body"
        else
          cat -- "$body"
        fi

        exit "$status"
      '';

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
