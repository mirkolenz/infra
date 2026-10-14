{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      home.packages = with pkgs; [
        rustc
        cargo
        rustfmt
        clippy
        rust-analyzer
      ];
      custom.bump.cargo = {
        lockfile = "Cargo.lock";
        text = "${lib.getExe pkgs.cargo} update";
      };
    };
}
