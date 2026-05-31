{
  lib,
  mkZellijPlugin,
  fetchFromGitHub,
  nix-update-script,
}:
mkZellijPlugin (_finalAttrs: {
  pname = "zellij-project-sidebar";
  version = "0-unstable-2026-03-15";

  src = fetchFromGitHub {
    owner = "AndrewBeniston";
    repo = "zellij-project-sidebar";
    rev = "b62fdcd638f5ed50a974ac082f0044c87f06c658";
    hash = "sha256-3mQk/kDdaS9hFL/cHpYACQdPEQwUgABf0/X6vkYENe0=";
  };

  cargoHash = "sha256-eDJw2g7uNvMOCbGQJ+MbaqyQgBUQ4+zlDHyPcOgX57E=";

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version=branch" ];
  };

  meta = {
    description = "Project sidebar plugin for Zellij";
    homepage = "https://github.com/AndrewBeniston/zellij-project-sidebar";
    license = lib.licenses.mit;
  };
})
