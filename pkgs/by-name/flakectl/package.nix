{ mkPythonApp }:
# Downstream flakes drive their own flake through `withFlags`,
# e.g. `pkgs.flakectl.withFlags { flake = self.outPath; cache = "..."; }`.
# It runs `nix` and `git` of the host, every other tool from the flake, which keeps it lean in CI.
mkPythonApp {
  script = "flakectl";
  description = "Build, deploy, and update the hosts and packages of this flake";
}
