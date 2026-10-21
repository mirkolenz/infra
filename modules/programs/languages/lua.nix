{
  flake.modules.generic.languages =
    { pkgs, ... }:
    {
      custom = {
        languages.lua = {
          files = [ "*.lua" ];
          editors.zed = {
            names = [ "Lua" ];
            extensions = [ "lua" ];
          };
          servers = [ "emmylua_ls" ];
          # Zed has no integration for the language server of StyLua.
          formatter.tool = "stylua";
        };

        lsp.servers.emmylua_ls = {
          package = pkgs.emmylua-ls;
          editors = {
            zed = {
              name = "emmylua";
              extension = "emmylua";
            };
            # Teach the server about the Neovim runtime so `vim.*` resolves in the
            # Lua files shipped by the nixvim config (see modules/nixvim/lua).
            neovim.config.settings.emmylua = {
              runtime.version = "LuaJIT";
              workspace.library = [ { __raw = "vim.env.VIMRUNTIME"; } ];
            };
          };
        };

        # Two spaces instead of the tabs of StyLua, also over the configuration of a project.
        tools.stylua = rec {
          package = pkgs.stylua;
          args = [
            "--search-parent-directories"
            "--respect-ignores"
            "--indent-type"
            "Spaces"
            "--indent-width"
            "2"
          ];
          stdinArgs = args ++ [
            "--stdin-filepath"
            "{file}"
            "-"
          ];
        };
      };
    };
}
