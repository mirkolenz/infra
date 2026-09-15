{
  flake.modules.nixvim.default = {
    lsp.keymaps = [
      {
        key = "g.";
        mode = [
          "n"
          "x"
        ];
        lspBufAction = "code_action";
        options.desc = "Code action";
      }
    ];
  };
}
