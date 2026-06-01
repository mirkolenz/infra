{
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}:
vimUtils.buildVimPlugin {
  pname = "direnv.nvim";
  version = "0-unstable-2026-05-14";
  src = fetchFromGitHub {
    owner = "NotAShelf";
    repo = "direnv.nvim";
    rev = "8962b7fe3f6267db9dd8b2a49f2c6175b7980210";
    hash = "sha256-S2AuTMOCiglrvB1mJWEDlSke130GWpnDvMuIapjMyFk=";
  };
  meta.homepage = "https://github.com/NotAShelf/direnv.nvim";
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version=branch" ];
  };
  strictDeps = true;
}
