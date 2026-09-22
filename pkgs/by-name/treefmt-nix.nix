# The repository formatter, built here so the flake's `formatter` and every home
# share one wrapper instead of a second treefmt-nix evaluation per system.
# https://github.com/NixOS/nixpkgs/blob/master/ci/default.nix
{
  inputs,
  pkgs,
}:
inputs.treefmt-nix.lib.mkWrapper pkgs {
  projectRootFile = "flake.nix";
  programs = {
    # keep-sorted start
    actionlint.enable = false;
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
  programs.ruff-check.package = pkgs.ruff-bin;
  programs.ruff-format.package = pkgs.ruff-bin;
}
