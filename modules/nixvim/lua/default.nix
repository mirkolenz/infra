# Sources the hand-written Lua modules in this directory as real `plugin/` files
# (referenced by source, not inlined into init), so they keep syntax
# highlighting, LSP support, and accurate stack traces. Neovim sources each
# plugin/ file once at startup. extraPackages puts the tools the modules shell
# out to on Neovim's PATH, so the features are self-contained.
{
  flake.modules.nixvim.default =
    { pkgs, ... }:
    {
      extraFiles = {
        "plugin/pdf-preview.lua".source = ./pdf-preview.lua;
        "plugin/typst.lua".source = ./typst.lua;
      };
      extraPackages = with pkgs; [
        imagemagick # snacks.image rendering backend
        poppler-utils # pdftoppm + pdfinfo for the paged PDF preview
        typst-bin # typst compile / watch
      ];
    };
}
