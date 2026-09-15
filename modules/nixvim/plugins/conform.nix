# conform.nvim owns formatting. It maps filetypes to CLI formatters in an
# explicit order, mirroring Zed's `languages.*.formatter` lists, and falls back
# to the language server for filetypes without an entry (nixd, tombi, lemminx,
# gopls, ...). Running the formatters as plain CLIs also sidesteps the workspace
# detection of their language server counterparts, so oxfmt formats a lone JSON
# file the same way it formats one inside a node project.
{
  flake.modules.nixvim.default =
    { lib, pkgs, ... }:
    let
      # `oxlint --fix` is the CLI equivalent of Zed's `source.fixAll.oxc` code
      # action. oxfmt has no astro parser, so astro only gets the linter half.
      oxc = [
        "oxlint"
        "oxfmt"
      ];
      # Mirrors Zed's `source.fixAll.ruff` and `source.organizeImports.ruff` code
      # actions, followed by the formatter itself.
      ruff = [
        "ruff_fix"
        "ruff_organize_imports"
        "ruff_format"
      ];
    in
    {
      plugins.conform-nvim = {
        enable = true;
        settings = {
          # Formatters are the source of truth; the language server only formats
          # filetypes without an entry in `formatters_by_ft` below.
          default_format_opts.lsp_format = "fallback";
          # conform takes `true` here and normalises it to an empty table, which
          # keeps every option above. An empty attrset cannot express that: nixvim
          # drops it from the generated config and formatting on write goes away.
          format_on_save.__raw = "true";
          # Filetypes such as csv, log or gitcommit have neither a formatter nor
          # a language server, which is not worth a warning on every write.
          notify_no_formatters = false;
          # Pin each formatter to its nixpkgs build, the way the language servers
          # pin their packages, rather than resolving it off `$PATH`. The ruff
          # entries all drive the same binary.
          formatters = lib.mapAttrs (_: pkg: { command = lib.getExe pkg; }) (
            {
              mago_format = pkgs.mago;
              oxfmt = pkgs.oxfmt;
              oxlint = pkgs.oxlint;
              stylua = pkgs.stylua;
              tex-fmt = pkgs.tex-fmt;
              typstyle = pkgs.typstyle;
            }
            // lib.genAttrs ruff (_: pkgs.ruff-bin)
          );
          formatters_by_ft = {
            # keep-sorted start block=yes
            astro = {
              __unkeyed-1 = "oxlint";
              lsp_format = "last";
            };
            bib = [ "tex-fmt" ];
            css = [ "oxfmt" ];
            graphql = [ "oxfmt" ];
            handlebars = [ "oxfmt" ];
            html = [ "oxfmt" ];
            javascript = oxc;
            javascriptreact = oxc;
            json = [ "oxfmt" ];
            json5 = [ "oxfmt" ];
            jsonc = [ "oxfmt" ];
            less = [ "oxfmt" ];
            lua = [ "stylua" ];
            markdown = [ "oxfmt" ];
            mdx = [ "oxfmt" ];
            php = [ "mago_format" ];
            python = ruff;
            scss = [ "oxfmt" ];
            tex = [ "tex-fmt" ];
            typescript = oxc;
            typescriptreact = oxc;
            typst = [ "typstyle" ];
            vue = oxc;
            yaml = [ "oxfmt" ];
            # keep-sorted end
          };
        };
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
