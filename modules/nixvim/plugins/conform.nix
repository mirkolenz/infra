# conform.nvim runs the shared fixers and formatters on save, and otherwise the
# formatting language server (see options/nixvim/editors.nix).
{
  flake.modules.nixvim.default = {
    plugins.conform-nvim.settings = {
      # conform takes `true` here and normalises it to an empty table, which
      # keeps the default format options. An empty attrset cannot express that: nixvim
      # drops it from the generated config and formatting on write goes away.
      format_on_save.__raw = "true";
      # Filetypes such as csv, log or gitcommit have neither a formatter nor
      # a language server, which is not worth a warning on every write.
      notify_no_formatters = false;
    };
    keymaps = [
      {
        key = "<leader>bf";
        mode = [
          "n"
          "x"
        ];
        action.__raw = ''function() require("conform").format() end'';
        options.desc = "Format buffer";
      }
    ];
  };
}
