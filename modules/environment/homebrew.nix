{
  flake.modules.darwin.default =
    let
      caskApps = [
        # keep-sorted start
        "1password"
        "1password-cli@beta"
        "affinity"
        "alt-tab"
        "anydesk"
        "arq"
        "balenaetcher"
        "betterdisplay"
        "chatgpt"
        "claude"
        "cyberduck"
        "daisydisk"
        "default-folder-x"
        "devonthink"
        "element"
        "figma"
        "firefox"
        "fission"
        "fujitsu-scansnap-home"
        "ghostty"
        "google-chrome"
        "handbrake-app"
        "microsoft-auto-update"
        "microsoft-teams"
        "obsidian"
        "omnigraffle"
        "openwork"
        "orbstack"
        "orion"
        "presentation"
        "raindropio"
        "raycast"
        "rode-central"
        "signal"
        "skim"
        "soundsource"
        "stats"
        "steermouse"
        "sublime-merge"
        "tailscale-app"
        "tiptoi-manager"
        "vicinae"
        "viscosity"
        "visual-studio-code"
        "vivaldi"
        "wifiman"
        "zed"
        "zoom"
        "zotero"
        # keep-sorted end
      ];

      caskFonts = map (name: "font-${name}") [
        # keep-sorted start
        "big-shoulders-display"
        "big-shoulders-inline-display"
        "big-shoulders-inline-text"
        "big-shoulders-stencil-display"
        "big-shoulders-stencil-text"
        "big-shoulders-text"
        "blex-mono-nerd-font"
        "cascadia-code"
        "cascadia-code-nf"
        "cascadia-mono"
        "caskaydia-cove-nerd-font"
        "eagle-lake"
        "eb-garamond"
        "expletus-sans"
        "fira-code"
        "fira-code-nerd-font"
        "fira-mono"
        "fira-sans"
        "geist"
        "geist-mono"
        "ia-writer-duo"
        "ia-writer-mono"
        "ia-writer-quattro"
        "ibm-plex-math"
        "ibm-plex-mono"
        "ibm-plex-sans"
        "ibm-plex-serif"
        "intel-one-mono"
        "inter"
        "intone-mono-nerd-font"
        "iosevka"
        "jetbrains-mono"
        "jetbrains-mono-nerd-font"
        "jost"
        "lugrasimo"
        "maple-mono"
        "maple-mono-nf"
        "monaspace"
        "monaspice-nerd-font"
        "overlock"
        "overlock-sc"
        "roboto"
        "roboto-flex"
        "roboto-mono"
        "roboto-serif"
        "roboto-slab"
        "source-code-pro"
        "source-sans-3"
        "source-serif-4"
        "tangerine"
        "tex-gyre-adventor"
        "tex-gyre-bonum"
        "tex-gyre-bonum-math"
        "tex-gyre-chorus"
        "tex-gyre-cursor"
        "tex-gyre-heros"
        "tex-gyre-pagella"
        "tex-gyre-pagella-math"
        "tex-gyre-schola"
        "tex-gyre-schola-math"
        "tex-gyre-termes"
        "tex-gyre-termes-math"
        "ubuntu"
        "ubuntu-condensed"
        "ubuntu-mono"
        "ubuntu-mono-nerd-font"
        "ubuntu-nerd-font"
        "ubuntu-sans"
        "ubuntu-sans-mono"
        "ubuntu-sans-nerd-font"
        "varela"
        "varela-round"
        # keep-sorted end
      ];
    in
    {
      homebrew = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        enableFishIntegration = true;
        global.autoUpdate = true;
        onActivation = {
          autoUpdate = true;
          upgrade = true;
          extraEnv = {
            HOMEBREW_NO_ENV_HINTS = "1";
          };
        };
        taps = [ ];
        brews = [ ];
        casks = caskApps ++ caskFonts;
      };
    };
}
