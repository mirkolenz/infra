{
  flake.modules.nixvim.default = {
    plugins.blink-cmp = {
      enable = true;
      settings = {
        signature.enabled = true;
        completion = {
          ghost_text.enabled = false;
          documentation = {
            auto_show = true;
            auto_show_delay_ms = 0;
            update_delay_ms = 50;
          };
          keyword.range = "full";
          list.selection = {
            auto_insert = false;
            preselect = false;
            # lib.nixvim.mkRaw /* lua */ ''
            #   function(ctx)
            #     return not require('blink.cmp').snippet_active({ direction = 1 })
            #   end
            # '';
          };
        };
        # https://cmp.saghen.dev/modes/cmdline.html
        cmdline = {
          completion.menu.auto_show = true;
          keymap = {
            "<Tab>" = [
              "show"
              "accept"
            ];
          };
        };
        # https://cmp.saghen.dev/configuration/keymap#presets
        keymap = {
          preset = "super-tab";
          "<CR>" = [
            "accept"
            "fallback"
          ];
        };
        sources = {
          default = [
            # "buffer"
            "lsp"
            "path"
            "snippets"
          ];
          providers = {
            lsp.async = true;
          };
        };
      };
    };
  };
}
