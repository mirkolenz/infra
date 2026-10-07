final: prev:
# Tools that run upstream Nix warn about every setting of Determinate's nix.conf
# that upstream does not know, so they get determinate-nix instead.
let
  inherit (prev) lib;
in
lib.genAttrs [
  "nix-update"
  "nixos-rebuild-ng"
  "nixpkgs-review"
  "nurl"
] (name: prev.${name}.override { nix = final.determinate-nix; })
// {
  # nix-eval-jobs stays on upstream Nix, since Determinate's fork hangs on fetches,
  # so its warnings are filtered instead. nix-fast-build runs `nix-eval-jobs.nix`.
  nix-eval-jobs = final.writeShellApplication {
    name = "nix-eval-jobs";
    runtimeInputs = [
      final.gnugrep
      prev.nix-eval-jobs
    ];
    text = ''
      exec 2> >(grep -avxE --line-buffered "warning: unknown (setting|experimental feature) '[^']*'" >&2)
      exec nix-eval-jobs "$@"
    '';
    passthru.nix = final.determinate-nix;
  };

  # embeds nix and nurl at compile time, so any override forces a long rebuild.
  # keep it on upstream nurl to hit the binary cache.
  nix-init = prev.nix-init.override { inherit (prev) nurl; };
}
