{ pkgs, ... }:
{
  programs.herdr = {
    enable = true;
    package = pkgs.herdr-bin;
    # https://herdr.dev/docs/configuration/
    settings = {
      theme.name = "terrminal";
      ui = {
        toast.delivery = "terminal";
        sound.enabled = true;
        show_agent_labels_on_pane_borders = true;
      };
    };
  };
}
