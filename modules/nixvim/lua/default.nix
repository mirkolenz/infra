# Sources the hand-written Lua files in this directory by reference,
# not inlined into init, so they keep syntax highlighting, LSP support,
# and accurate stack traces. Neovim sources each plugin/ file once at startup,
# and lua/my/ holds the helpers they share. extraPackages
# and dependencies put the tools the modules shell out to on Neovim's PATH,
# so the features are self-contained.
{ lib', ... }:
{
  flake.modules.nixvim = {
    default.extraFiles = {
      "lua/my/system.lua".source = ./system.lua;
      "plugin/autodir.lua".source = ./autodir.lua;
      "plugin/ui2.lua".source = ./ui2.lua;
    };
    extras =
      { pkgs, ... }:
      {
        extraFiles = {
          "plugin/pdf-preview.lua".source = ./pdf-preview.lua;
          "plugin/typst.lua".source = ./typst.lua;
        };
        # pdftoppm and pdfinfo for the paged PDF preview
        extraPackages = [ pkgs.poppler-utils ];
        dependencies.typst = {
          enable = true;
          package = pkgs.typst-bin;
        };
        keymaps = lib'.mkVimKeymaps { raw = false; } [
          {
            key = "<leader>tp";
            action = "PdfPreview";
            options.desc = "Toggle PDF preview";
          }
        ];
        files."after/ftplugin/typst.lua".keymaps = lib'.mkVimKeymaps { raw = false; } [
          {
            key = "<leader>tb";
            action = "TypstCompile";
            options.desc = "Compile the document";
          }
          {
            key = "<leader>tw";
            action = "TypstWatch";
            options.desc = "Watch and recompile the document";
          }
          {
            key = "<leader>tW";
            action = "TypstWatchStop";
            options.desc = "Stop watching the document";
          }
        ];
      };
  };
}
