# Per-filetype settings, wired through nixvim's `files` option.
# `localOpts` (vim.opt_local) is required here: plain `opts` maps to `vim.opt`,
# i.e. `:set`, which for buffer-local options such as shiftwidth also overwrites
# the global value inherited by every buffer opened afterwards.
# `after/ftplugin` runs last, so these win over ftplugins shipped by the Neovim
# runtime or by plugins.
let
  # Prose filetypes (LaTeX, Typst, Markdown, plain text) soft-wrap.
  # Indent width is inherited from the global opts.
  proseOpts.wrap = true;
in
{
  flake.modules.nixvim.default = {
    files = {
      "after/ftplugin/markdown.lua".localOpts = proseOpts;
      "after/ftplugin/python.lua" = {
        localOpts = {
          shiftwidth = 4;
          tabstop = 4;
        };
      };
      "after/ftplugin/tex.lua".localOpts = proseOpts;
      "after/ftplugin/text.lua".localOpts = proseOpts;
      "after/ftplugin/typst.lua".localOpts = proseOpts;
    };
  };
}
