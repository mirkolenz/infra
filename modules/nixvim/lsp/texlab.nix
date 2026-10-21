{ lib', ... }:
{
  flake.modules.nixvim.extras = {
    files."after/ftplugin/tex.lua" = {
      # Builds run on demand, and the PDF previews inline with vim.ui.img
      # (see ../lua/pdf-preview.lua) instead of forwarding to a GUI viewer.
      keymaps = lib'.mkVimKeymaps { raw = false; } [
        {
          key = "<leader>tb";
          action = "TexlabWriteBuild";
          options.desc = "Write and build the document";
        }
        {
          key = "<leader>tB";
          action = "LspTexlabCancelBuild";
          options.desc = "Cancel the current build";
        }
        {
          key = "<leader>tc";
          action = "LspTexlabCleanAuxiliary";
          options.desc = "Clean auxiliary files";
        }
        {
          key = "<leader>tC";
          action = "LspTexlabCleanArtifacts";
          options.desc = "Clean auxiliary and output files";
        }
      ];
      userCommands.TexlabWriteBuild = {
        command = "write | LspTexlabBuild";
        desc = "Write and build the document";
      };
    };
  };
}
