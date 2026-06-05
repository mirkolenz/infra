# https://github.com/NixOS/nixpkgs/blob/master/ci/default.nix
{
  perSystem =
    { config, pkgs, ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";
        programs = {
          # keep-sorted start
          actionlint.enable = true;
          buf.enable = true;
          gofmt.enable = true;
          keep-sorted.enable = true;
          nixf-diagnose.enable = true;
          nixfmt.enable = true;
          oxfmt.enable = true;
          php-cs-fixer.enable = true;
          ruff-check.enable = true;
          ruff-format.enable = true;
          rustfmt.enable = true;
          texfmt.enable = true;
          typstyle.enable = true;
          yamlfmt.enable = true;
          # keep-sorted end
        };
        programs.nixf-diagnose = {
          variableLookup = true;
          ignore = [
            # unknown builtin `getFlake`
            "sema-primop-unknown"
          ];
        };
        programs.nixfmt.package = pkgs.nixfmt-rs;
      };
      packages.treefmt-nix = config.treefmt.build.wrapper;
    };
}
