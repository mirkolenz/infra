{
  pkgs,
  lib,
  config,
  ...
}:
let
  herdr = lib.getExe config.programs.herdr.package;
  # Spawn a new herdr tab running a command, labelled after it (override with -n).
  # With no command, launch the default shell in a tab labelled "shell".
  htab = pkgs.writeShellApplication {
    name = "htab";
    text = ''
      if [ "''${1:-}" = "-n" ]; then
        name="$2"
        shift 2
      fi
      if [ "$#" -lt 1 ]; then
        set -- "${lib.getExe pkgs.fish}"
        name="''${name:-shell}"
      fi
      pane_id="$(${lib.getExe config.programs.herdr.package} tab create --label "''${name:-$1}" --focus | ${lib.getExe pkgs.jq} -r '.result.root_pane.pane_id')"
      exec ${lib.getExe config.programs.herdr.package} pane run "$pane_id" "$*"
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
        # Reuse the htab command via a background shell to open the command in a new tab.
        command = [
          {
            key = "prefix+alt+g";
            type = "shell";
            command = "htab lazygit";
          }
          {
            key = "prefix+alt+e";
            type = "shell";
            command = "htab nvim";
          }
          {
            key = "prefix+alt+y";
            type = "shell";
            command = "htab yabai";
          }
        ];
      };
      ui = {
        toast.delivery = "terminal";
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
}
