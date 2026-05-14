{
  lib,
  writers,
  python3Packages,
  gh,
  git,
  determinate-nix,
  darwin-rebuild,
  nixos-rebuild-ng,
  home-manager,
  inputs,
}:
writers.writePython3Bin "flakectl" {
  libraries = with python3Packages; [ typer ];
  doCheck = false;
  makeWrapperArgs = [
    "--add-flag"
    "--nix-exe=${lib.getExe determinate-nix}"
    "--add-flag"
    "--nix-shell-exe=${lib.getExe' determinate-nix "nix-shell"}"
    "--add-flag"
    "--git-exe=${lib.getExe git}"
    "--add-flag"
    "--gh-exe=${lib.getExe gh}"
    "--add-flag"
    "--nixpkgs=${inputs.nixpkgs.outPath}"
    "--add-flag"
    "--darwin-builder=${lib.getExe darwin-rebuild}"
    "--add-flag"
    "--linux-builder=${lib.getExe nixos-rebuild-ng}"
    "--add-flag"
    "--home-builder=${lib.getExe home-manager}"
  ];
} ./script.py
