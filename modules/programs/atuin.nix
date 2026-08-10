{
  flake.modules.homeManager.default =
    { ... }:
    {
      programs.atuin = {
        enable = true;
        daemon.enable = true;
        flags = [
          # "--disable-up-arrow"
          # "--disable-ctrl-r"
        ];
        # https://docs.atuin.sh/latest/configuration/config/
        settings = {
          # keep-sorted start
          enter_accept = true;
          inline_height = 0;
          inline_height_shell_up_key_binding = 10;
          keymap_mode = "vim-insert";
          search_mode = "fuzzy";
          sync_address = "https://atuin.lenz.casa";
          sync_frequency = "1h";
          update_check = false;
          workspaces = true;
          # keep-sorted end
        };
      };
    };
}
