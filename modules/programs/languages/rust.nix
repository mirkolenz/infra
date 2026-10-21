{
  flake.modules.generic.languages =
    { pkgs, ... }:
    {
      custom = {
        languages.rust = {
          files = [ "*.rs" ];
          editors.zed.names = [ "Rust" ];
          servers = [ "rust_analyzer" ];
          # rust-analyzer only finds rustfmt on the PATH, so the editors run it themselves.
          formatter.tool = "rustfmt";
        };

        lsp.servers.rust_analyzer = {
          package = pkgs.rust-analyzer;
          editors.zed.name = "rust-analyzer";
        };

        # rustfmt reads no Cargo.toml, so the edition comes from rustfmt.toml or this default.
        tools.rustfmt = {
          package = pkgs.rustfmt;
          args = [
            "--edition"
            "2024"
            # Each file gets formatted on its own, not along with its modules.
            "--config"
            "skip_children=true"
          ];
          stdinArgs = [
            "--edition"
            "2024"
          ];
        };
      };
    };
}
