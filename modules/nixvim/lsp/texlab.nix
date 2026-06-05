{
  flake.modules.nixvim.default =
    { pkgs, ... }:
    {
      lsp.servers.texlab = {
        enable = true;
        config.settings.texlab = {
          bibtexFormatter = "tex-fmt";
          latexFormatter = "tex-fmt";
          inlayHints = {
            labelDefinitions = false;
            labelReferences = false;
            maxLength = 32;
          };
          build = {
            onSave = false;
            forwardSearchAfter = true;
          };
          # https://github.com/latex-lsp/texlab/wiki/Previewing
          # https://github.com/rzukic/zed-latex/blob/main/src/texlab_workspace_config/preview_presets.rs
          forwardSearch =
            if pkgs.stdenv.isDarwin then
              {
                # displayline -h
                executable = "displayline";
                args = [
                  "-r"
                  "-g"
                  "%l"
                  "%p"
                  "%f"
                ];
              }
            else
              {
                executable = "zathura";
                args = [
                  "--synctex-forward"
                  "%l:1:%f"
                  "%p"
                ];
              };
        };
      };
    };
}
