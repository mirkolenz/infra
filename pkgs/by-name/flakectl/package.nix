{ mkPythonApp }:
# Downstream flakes import the flake-parts module `modules.flake.flakectl` of infra,
# which makes it their default app, and set its `flakectl.flags`, e.g. `cache = "...";`.
# It runs `nix` and `git` of the host, every other tool from the flake, which keeps it lean in CI.
mkPythonApp {
  script = "flakectl";
  description = "Build, deploy, and update the hosts and packages of this flake";
}
