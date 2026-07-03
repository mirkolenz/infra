{
  flake.modules.nixvim.default =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      globals = lib.mkIf config.plugins.copilot-vim.enable {
        copilot_settings = {
          # selectedCompletionModel = "";
        };
        copilot_no_maps = true;
      };
      keymaps = lib.mkIf config.plugins.copilot-vim.enable [
        {
          key = "<M-;>";
          mode = "i";
          action = "copilot#Accept()";
          options = {
            expr = true;
            silent = true;
            nowait = true;
            replace_keycodes = false;
            desc = "Accept Copilot suggestion";
          };
        }
        {
          key = "<M-l>";
          mode = "i";
          action = "copilot#AcceptLine()";
          options = {
            expr = true;
            silent = true;
            nowait = true;
            replace_keycodes = false;
            desc = "Accept Copilot line";
          };
        }
        {
          key = "<M-k>";
          mode = "i";
          action = "copilot#AcceptWord()";
          options = {
            expr = true;
            silent = true;
            nowait = true;
            replace_keycodes = false;
            desc = "Accept Copilot word";
          };
        }
        {
          key = "<M-'>";
          mode = "i";
          action = "<cmd>call copilot#Dismiss()<CR>";
          options = {
            silent = true;
            nowait = true;
            desc = "Dismiss Copilot suggestion";
          };
        }
        {
          key = "<M-n>";
          mode = "i";
          action = "<cmd>call copilot#Next()<CR>";
          options = {
            silent = true;
            nowait = true;
            desc = "Next Copilot suggestion";
          };
        }
        {
          key = "<M-p>";
          mode = "i";
          action = "<cmd>call copilot#Previous()<CR>";
          options = {
            silent = true;
            nowait = true;
            desc = "Next Copilot suggestion";
          };
        }
        {
          key = "<M-j>";
          mode = "i";
          action = "<cmd>call copilot#Suggest()<CR>";
          options = {
            silent = true;
            nowait = true;
            desc = "Trigger Copilot suggestion";
          };
        }
      ];
      plugins.copilot-vim = {
        enable = false;
        settings = {
          filetypes = {
            "*" = true;
          };
          node_command = lib.getExe pkgs.nodejs;
        };
      };
      plugins.copilot-lua = {
        enable = true;
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
