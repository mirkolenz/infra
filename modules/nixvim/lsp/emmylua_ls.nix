{
  flake.modules.nixvim.extras =
    { lib, ... }:
    {
      lsp.servers.emmylua_ls = {
        enable = true;
        # Teach the server about the Neovim runtime so `vim.*` resolves in the
        # Lua files shipped by this config (see ../lua).
        config.settings.emmylua = {
          runtime.version = "LuaJIT";
          workspace.library = [ (lib.nixvim.mkRaw "vim.env.VIMRUNTIME") ];
        };
      };
    };
}
