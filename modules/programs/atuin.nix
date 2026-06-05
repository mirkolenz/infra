{
  flake.modules.homeManager.default =
    { ... }:
    {
      programs.atuin = {
        enable = false;
        flags = [
          "--disable-up-arrow"
          # "--disable-ctrl-r"
        ];
        # https://docs.atuin.sh/configuration/config/
        settings = {
          auto_sync = true;
          sync_frequency = "1h";
          update_check = false;
          search_mode = "fuzzy";
          enter_accept = true;
          keymap_mode = "vim-insert";
          sync.records = true;
          dotfiles.enabled = false;
        };
      };
    };
}
