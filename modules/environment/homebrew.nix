{
  flake.modules.darwin.default =
    let
      caskApps = [
        # keep-sorted start
        "1password"
        "affinity"
        "alt-tab"
        "anydesk"
        "arq"
        "balenaetcher"
        "betterdisplay"
        "chatgpt"
        "claude"
        "codex-app"
        "cotabby"
        "daisydisk"
        "default-folder-x"
        "devonthink"
        "element"
        "figma"
        "firefox"
        "fission"
        "forklift"
        "fujitsu-scansnap-home"
        "ghostty"
        "google-chrome"
        "handbrake-app"
        "lm-studio"
        "macwhisper"
        "microsoft-auto-update"
        "microsoft-teams"
        "obsidian"
        "omnigraffle"
        "orbstack"
        "orion"
        "presentation"
        "raindropio"
        "raycast"
        "rode-central"
        "skim"
        "soundsource"
        "stats"
        "steermouse"
        "sublime-merge"
        "tailscale-app"
        "tiptoi-manager"
        "viscosity"
        "visual-studio-code"
        "vivaldi"
        "wifiman"
        "zed"
        "zoom"
        "zotero"
        # keep-sorted end
      ];

      # mas list
      masApps = {
        # keep-sorted start
        ausweisapp = 948660805;
        base = 6744867438;
        bitwarden = 1352778147;
        dropover = 1355679052;
        gapplin = 768053424;
        home-assistant = 1099568401;
        keka = 470158793;
        mela = 1568924476;
        microsoft-excel = 462058435;
        microsoft-onedrive = 823766827;
        microsoft-powerpoint = 462062816;
        microsoft-word = 462054704;
        parallels = 1085114709;
        pdf-expert = 1055273043;
        # pdf-presenter = 6472296409;
        qr-factory = 1609285899;
        reeder = 6475002485;
        safari-1password = 1569813296;
        safari-kagi = 1622835804;
        safari-raindropio = 1549370672;
        step-two = 1448916662;
        testflight = 899247664;
        todoist = 585829637;
        whatsapp = 310633997;
        # keep-sorted end
      };

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
          # cleanup = "uninstall"; # todo: broken as of 2026-06-04
          upgrade = true;
          extraEnv = {
            HOMEBREW_NO_ENV_HINTS = "1";
          };
        };
        taps = [
          "fujacob/cotabby"
        ];
        brews = [ ];
        casks = caskApps ++ caskFonts;
        inherit masApps;
      };
    };
}
