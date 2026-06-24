{
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}:
vimUtils.buildVimPlugin {
  pname = "direnv.nvim";
  version = "0-unstable-2026-06-23";
  src = fetchFromGitHub {
    owner = "NotAShelf";
    repo = "direnv.nvim";
    rev = "444fad801fc67325ed502e526a90f8d875b3dc25";
    hash = "sha256-ein9IK0rzGsr0DPkkTpMRxvj9MmxBCh5MgR9Cj7HoOs=";
  };
  meta.homepage = "https://github.com/NotAShelf/direnv.nvim";
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version=branch" ];
  };
  strictDeps = true;
}
