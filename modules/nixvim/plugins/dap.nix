{
  flake.modules.nixvim.default = {
    plugins = {
      dap.enable = true;
      dap-python.enable = true;
      dap-virtual-text.enable = true;
      dap-ui.enable = true;
    };
  };
}
