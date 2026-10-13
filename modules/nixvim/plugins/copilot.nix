{
  flake.modules.nixvim.default =
    { lib, pkgs, ... }:
    {
      plugins.copilot-lua = {
        enable = false;
        settings = {
          filetypes = {
            "*" = true;
          };
          panel = {
            enabled = true;
            auto_refresh = true;
            keymap = {
              jump_prev = "[[";
              jump_next = "]]";
              accept = "<CR>";
              refresh = "gr";
              open = "<M-CR>";
            };
            layout = {
              position = "bottom";
              ratio = 0.4;
            };
          };
          suggestion = {
            enabled = true;
            auto_trigger = true;
            hide_during_completion = false;
            keymap = {
              accept = "<M-;>";
              accept_line = "<M-l>";
              accept_word = "<M-k>";
              dismiss = "<M-'>";
              next = "<M-n>";
              prev = "<M-p>";
            };
          };
          copilot_node_command = lib.getExe pkgs.nodejs;
          # copilot_model = "";
          server = {
            type = "binary";
            custom_server_filepath = lib.getExe pkgs.copilot-language-server;
          };
        };
      };
    };
}
