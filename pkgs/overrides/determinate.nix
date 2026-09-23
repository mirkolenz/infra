final: prev:
# Tools that run upstream Nix warn about every setting of Determinate's nix.conf
# that upstream does not know, so they get determinate-nix instead.
# nix-fast-build follows through nix-eval-jobs.
let
  inherit (prev) lib;
  inherit (prev.stdenv.hostPlatform) system;
in
lib.genAttrs
  [
    "nix-init"
    "nix-update"
    "nixos-rebuild-ng"
    "nixpkgs-review"
    "nurl"
  ]
  (name: prev.${name}.override { nix = final.determinate-nix; })
// {
  # taken from the flake's own package set like determinate-nix, extended by the
  # attributes of nixpkgs' nix-eval-jobs that dependents rely on
  nix-eval-jobs = final.inputs.nix-eval-jobs.packages.${system}.default.overrideAttrs (prevAttrs: {
    passthru = prevAttrs.passthru // {
      nix = final.determinate-nix;
    };
    meta = prevAttrs.meta // {
      mainProgram = "nix-eval-jobs";
    };
  });
}
