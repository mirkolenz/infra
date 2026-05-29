{ pkgs, ... }:
{
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
        command = [
          {
            key = "prefix+alt+g";
            type = "pane";
            command = "lazygit";
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
