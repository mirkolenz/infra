# Sources the hand-written Lua files in this directory by reference,
# not inlined into init, so they keep syntax highlighting, LSP support,
# and accurate stack traces. Neovim sources each plugin/ file once at startup,
# and lua/my/ holds the helpers they share. extraPackages
# and dependencies put the tools the modules shell out to on Neovim's PATH,
# so the features are self-contained.
{
  flake.modules.nixvim.default =
    { pkgs, ... }:
    {
      extraFiles = {
        "lua/my/system.lua".source = ./system.lua;
        "plugin/autodir.lua".source = ./autodir.lua;
        "plugin/pdf-preview.lua".source = ./pdf-preview.lua;
        "plugin/typst.lua".source = ./typst.lua;
        "plugin/ui2.lua".source = ./ui2.lua;
      };
      # pdftoppm and pdfinfo for the paged PDF preview
      extraPackages = [ pkgs.poppler-utils ];
      dependencies.typst = {
        enable = true;
        package = pkgs.typst-bin;
      };
    };
}
