{
  flake.modules.nixvim.extras = {
    lsp.servers.tinymist = {
      enable = true;
      config.settings = {
        exportPdf = "never";
        outputPath = "$root/$name";
      };
    };
  };
}
