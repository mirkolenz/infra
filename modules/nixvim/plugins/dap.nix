{
  flake.modules.nixvim.extras = {
    plugins = {
      dap.enable = true;
      dap-python.enable = true;
      dap-view.enable = true;
      dap-virtual-text.enable = true;
    };
  };
}
