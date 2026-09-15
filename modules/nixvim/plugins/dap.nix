{
  flake.modules.nixvim.default =
    { pkgs, ... }:
    {
      plugins = {
        dap.enable = true;
        dap-python.enable = true;
        dap-virtual-text.enable = true;
        dap-ui.enable = true;
      };
      # nvim-dap-ui requires nvim-nio at runtime but nixvim's module does not pull
      # it in, so `require("dapui").setup()` raised and aborted the rest of init.
      extraPlugins = [ pkgs.vimPlugins.nvim-nio ];
    };
}
