final: prev:
# Tools that run upstream Nix warn about every setting of Determinate's nix.conf
# that upstream does not know, so they get determinate-nix instead.
# nix-fast-build follows through nix-eval-jobs.
let
  inherit (prev) lib;
  inherit (prev.stdenv.hostPlatform) system;
in
lib.genAttrs [
  "nix-update"
  "nixos-rebuild-ng"
  "nixpkgs-review"
  "nurl"
] (name: prev.${name}.override { nix = final.determinate-nix; })
// {
  # embeds nix and nurl at compile time, so any override forces a long rebuild.
  # keep it on upstream nurl to hit the binary cache.
  nix-init = prev.nix-init.override { inherit (prev) nurl; };

  # taken from the flake's own package set like determinate-nix, extended by the
  # attributes of nixpkgs' nix-eval-jobs that dependents rely on
  nix-eval-jobs = final.inputs.nix-eval-jobs.packages.${system}.default.overrideAttrs (prevAttrs: {
    # TODO: drop once the fork includes NixOS/nix-eval-jobs#435 (2.35.1).
    # A worker restarting on the last job made a successful evaluation exit 1.
    patches = prevAttrs.patches or [ ] ++ [
      (final.fetchpatch {
        url = "https://github.com/NixOS/nix-eval-jobs/commit/1dfd85ae68393aa7db55f1dd005e0feab92c844b.patch";
        excludes = [ "tests-functional/*" ];
        hash = "sha256-64Qn3WwrhD+0vIdQZ4knRBb67msku7uyY7A64FdECxk=";
      })
    ];
    passthru = prevAttrs.passthru // {
      nix = final.determinate-nix;
    };
    meta = prevAttrs.meta // {
      mainProgram = "nix-eval-jobs";
    };
  });
}
