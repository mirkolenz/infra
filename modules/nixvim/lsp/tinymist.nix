{
  flake.modules.nixvim.default = {
    lsp.servers.tinymist = {
      enable = true;
      config.settings = {
        exportPdf = "never";
        outputPath = "$root/$name";
      };
    };
  };
}
