# The options of Neovim, whose integration is options/nixvim/editors.nix.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  language =
    { name, ... }:
    {
      options.editors.neovim.names = mkOption {
        type = with types; listOf str;
        default = [ name ];
        description = "Neovim filetypes of the language.";
      };
    };

  tool.options.editors.neovim.exitCodes = mkOption {
    type = with types; listOf int;
    default = [ 0 ];
    description = "Exit codes on which conform.nvim keeps the output, which it otherwise discards.";
  };

  server.options.editors.neovim.config = mkOption {
    type = with types; attrsOf anything;
    default = { };
    example.settings.Lua.workspace.library.__raw = "vim.api.nvim_get_runtime_file('', true)";
    description = "Further nixvim server configuration, for values that only Lua can express.";
  };
}
