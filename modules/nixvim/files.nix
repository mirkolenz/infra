# Per-filetype (ftplugin) nixvim settings, wired through nixvim's `files` option
# so they stay buffer-local instead of leaking into the global opts.
let
  # Prose filetypes (LaTeX, Typst, Markdown, plain text) share indent and
  # soft-wrap settings.
  proseOpts = {
    shiftwidth = 2;
    tabstop = 2;
    wrap = true;
  };
in
{
  flake.modules.nixvim.default = {
    files = {
      "ftplugin/markdown.lua".opts = proseOpts;
      "ftplugin/python.lua" = {
        opts = {
          shiftwidth = 4;
          tabstop = 4;
        };
      };
      "ftplugin/tex.lua" = {
        opts = proseOpts;
        keymaps = [
          {
            key = "<leader>tb";
            mode = "n";
            action = "<cmd>TexlabWriteBuild<CR>";
            options.desc = "Write and build the document";
          }
          {
            key = "<leader>tB";
            mode = "n";
            action = "<cmd>LspTexlabCancelBuild<CR>";
            options.desc = "Cancel the current build";
          }
          {
            key = "<leader>tc";
            mode = "n";
            action = "<cmd>LspTexlabCleanAuxiliary<CR>";
            options.desc = "Clean auxiliary files";
          }
          {
            key = "<leader>tC";
            mode = "n";
            action = "<cmd>LspTexlabCleanArtifacts<CR>";
            options.desc = "Clean auxiliary and output files";
          }
        ];
        userCommands = {
          TexlabWriteBuild = {
            command = "write | LspTexlabBuild";
            desc = "Write and build the document";
          };
        };
      };
      "ftplugin/text.lua".opts = proseOpts;
      "ftplugin/typst.lua" = {
        opts = proseOpts;
        keymaps = [
          {
            key = "<leader>tb";
            mode = "n";
            action = "<cmd>TypstCompile<CR>";
            options.desc = "Compile the document";
          }
          {
            key = "<leader>tw";
            mode = "n";
            action = "<cmd>TypstWatch<CR>";
            options.desc = "Watch and recompile the document";
          }
          {
            key = "<leader>tW";
            mode = "n";
            action = "<cmd>TypstWatchStop<CR>";
            options.desc = "Stop watching the document";
          }
        ];
      };
    };
  };
}
