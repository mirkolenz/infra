{
  flake.modules.nixvim.default = {
    lsp.keymaps = [
      {
        key = "<leader>bf";
        mode = [
          "n"
          "x"
        ];
        lspBufAction = "format";
        options.desc = "Format buffer";
      }
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
