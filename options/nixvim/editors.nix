# Maps the shared languages of options/shared/_editors onto nixvim: the servers onto
# its language servers, whose root detection and other defaults come from nvim-lspconfig,
# and the fixers and formatters onto conform.nvim.
{ config, lib, ... }:
let
  inherit (config.custom) active editors languages;

  mkServer = server: {
    # On the PATH as well, which the root detection of nvim-lspconfig probes for some servers.
    enable = true;
    inherit (server) package;
    config = lib.mkMerge [
      {
        # A server can drop it with `editors.neovim.config.cmd = null`,
        # to keep a dynamic command of nvim-lspconfig.
        cmd = lib.mkDefault ([ server.command ] ++ server.args);
        settings = lib.mkIf (server.settings != { }) server.settings;
        init_options = lib.mkIf (server.initializationOptions != { }) server.initializationOptions;
        # Without languages, the server keeps the filetypes of nvim-lspconfig.
        filetypes = lib.mkIf (server.languages != [ ]) (
          lib.unique (lib.concatMap (id: languages.${id}.editors.neovim.names) server.languages)
        );
      }
      server.editors.neovim.config
    ];
  };

  # conform looks up each component of a compound filetype on its own.
  filetypes = lib.mapAttrs' (
    filetype: lib.nameValuePair (lib.last (lib.splitString "." filetype))
  ) editors.neovim;

  # Without a formatter, the formatting server formats last.
  mkFiletype =
    language:
    lib.nixvim.listToUnkeyedAttrs language.formatting
    // lib.optionalAttrs (language.formatter.server != null) { lsp_format = "last"; };
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  imports = [ ../shared/_editors ];

  config = {
    lsp.servers = lib.mapAttrs (_: mkServer) active.servers;

    plugins.conform-nvim = {
      enable = true;
      settings = {
        formatters = lib.mapAttrs (_: tool: {
          inherit (tool) command;
          stdin = tool.stdinArgs != null;
          args =
            if tool.stdinArgs != null then tool.stdinArgsWith "$FILENAME" else tool.args ++ [ "$FILENAME" ];
          exit_codes = tool.editors.neovim.exitCodes;
        }) (lib.filterAttrs (_: tool: !tool.linter) active.tools);
        formatters_by_ft = lib.mapAttrs (_: mkFiletype) (
          lib.filterAttrs (_: language: language.formatting != [ ]) filetypes
        );
        # Only the formatting server of a language formats, and only for the filetypes
        # without a formatter.
        default_format_opts = {
          lsp_format = "fallback";
          filter.__raw = ''
            function(client) return vim.list_contains(${
              lib.nixvim.toLuaObject (lib.attrNames (lib.filterAttrs (_: server: server.formats) active.servers))
            }, client.name) end
          '';
        };
      };
    };
  };
}
