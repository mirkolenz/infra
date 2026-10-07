{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      home.sessionVariables.RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;
      home.packages = with pkgs; [
        rustc
        cargo
        rustfmt
        clippy
        rust-analyzer
      ];
      custom.bump.cargo = {
        pathspecs = [ "Cargo.lock" ];
        text = "${lib.getExe pkgs.cargo} update";
      };
    };
}
