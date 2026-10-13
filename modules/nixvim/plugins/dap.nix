{
  flake.modules.nixvim.default = {
    plugins = {
      dap.enable = true;
      dap-python.enable = true;
      dap-view.enable = true;
      dap-virtual-text.enable = true;
    };
  };
}
