{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      programs.cargo = {
        enable = true;
        # https://doc.rust-lang.org/cargo/reference/config.html
        settings = {
          registry.global-min-publish-age = "${toString config.custom.minReleaseAge.crates} days";
          # prefers the dependency versions supporting the rust-version of a package, the default of edition 2024
          resolver.incompatible-rust-versions = "fallback";
        };
      };
      home.packages = with pkgs; [
        rustc
        clippy
      ];
      custom.bump.cargo = {
        lockfile = "Cargo.lock";
        commands = [
          [
            (lib.getExe config.programs.cargo.package)
            "update"
          ]
        ];
      };
    };
}
