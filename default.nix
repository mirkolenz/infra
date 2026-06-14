# Non-flake entry point: evaluates the overlaid package set from the working
# tree, the shape `nix-update` and `flakectl update-pkgs` expect from
# `import ./. { }`. See https://github.com/Mic92/nix-update/blob/main/nix_update/eval.py
{
  system ? builtins.currentSystem,
  ...
}:
let
  flake = builtins.getFlake ("git+file://" + toString ./.);
  # Import `./pkgs` directly rather than the flake's store-copied
  # `overlays.default`, so `meta.position` stays in the working tree and
  # updateScripts can edit package files in place.
  overlay = import ./pkgs flake.overlayArgs;
in
import flake.inputs.nixpkgs {
  inherit system;
  overlays = [ overlay ];
  config = flake.nixpkgsConfig;
}
