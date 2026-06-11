{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      herdr = lib.getExe config.programs.herdr.package;

      # Open a new focused herdr tab and run the given command in it, labelling
      # the tab after the command's program name. (herdr has no single-command
      # equivalent, so we create the tab and run in its root pane in two steps.)
      htab = pkgs.writeShellApplication {
        name = "htab";
        text = ''
          pane_id="$(${herdr} tab create --label "$1" --focus | ${lib.getExe pkgs.jq} -r '.result.root_pane.pane_id')"
          exec ${herdr} pane run "$pane_id" "$*"
        '';
      };
    in
    {
      home.packages = [ htab ];
      programs.herdr = {
        enable = true;
        package = pkgs.herdr-bin;
        # https://herdr.dev/docs/configuration/
        settings = {
          onboarding = false;
          theme.name = "gruvbox";
          terminal = {
            default_shell = "fish";
            new_cwd = "follow";
          };
          keys = {
            prefix = "ctrl+b";
            # tmux-style jump back to the previously focused pane (across tabs/workspaces).
            last_pane = "prefix+;";
            # Reuse the htab command via a background shell to open the command in a new tab.
            command = [
              {
                key = "prefix+alt+g";
                type = "shell";
                command = "htab lazygit";
                description = "lazygit in a new tab";
              }
              {
                key = "prefix+alt+e";
                type = "shell";
                command = "htab nvim";
                description = "nvim in a new tab";
              }
              {
                key = "prefix+alt+y";
                type = "shell";
                command = "htab yabai";
                description = "yabai in a new tab";
              }
            ];
          };
          ui = {
            toast = {
              delivery = "terminal";
              herdr.position = "bottom-right";
              clipboard.position = "bottom-right";
            };
            sound.enabled = false;
            agent_panel_scope = "all";
            show_agent_labels_on_pane_borders = true;
            prompt_new_tab_name = true;
          };
          session = {
            resume_agents_on_restore = false;
          };
        };
      };
    };
}
