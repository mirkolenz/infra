{
  flake.modules.nixvim.default =
    { lib, ... }:
    {
      lsp.servers.lua_ls = {
        enable = true;
        # Teach the server about the Neovim runtime so `vim.*` resolves in the
        # Lua files shipped by this config (see ../lua).
        config.settings.Lua = {
          runtime.version = "LuaJIT";
          workspace = {
            checkThirdParty = false;
            library = [ (lib.nixvim.mkRaw "vim.env.VIMRUNTIME") ];
          };
        };
      };
    };
}
