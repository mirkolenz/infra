{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.withDisplay {
      programs.ghostty = {
        enable = true;
        package = if pkgs.stdenv.isDarwin then null else pkgs.ghostty;
        # https://ghostty.org/docs/config/reference
        settings = {
          auto-update = "download";
          auto-update-channel = "stable";
          background-blur = false;
          cursor-click-to-move = true;
          font-family = "JetBrainsMono Nerd Font";
          font-size = if pkgs.stdenv.isDarwin then 13 else 11;
          font-thicken = true;
          macos-titlebar-style = "tabs";
          notify-on-command-finish = "unfocused";
          notify-on-command-finish-action = "bell,notify";
          notify-on-command-finish-after = "10s";
          quick-terminal-position = "center";
          quick-terminal-size = "1000px,600px";
          shell-integration = "none";
          shell-integration-features = "no-cursor,sudo,title,ssh-env";
          split-inherit-working-directory = true;
          tab-inherit-working-directory = true;
          theme = "light:Gruvbox Light Hard,dark:Gruvbox Dark Hard";
          window-height = 30;
          window-inherit-working-directory = false;
          window-padding-x = 8;
          window-padding-y = 8;
          window-width = 120;
          keybind = [
            "global:alt+backquote=toggle_quick_terminal"
          ];
        };
      };
    };
}
