{
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}:
vimUtils.buildVimPlugin {
  pname = "direnv.nvim";
  version = "0-unstable-2026-06-07";
  src = fetchFromGitHub {
    owner = "NotAShelf";
    repo = "direnv.nvim";
    rev = "e623d3645152839cbe7e73e7b2aa6e31256020ea";
    hash = "sha256-Bwdkf1ZHPsR3BUxdsGBNNNbzJ/CPOIlqb5EcQUUPuAk=";
  };
  meta.homepage = "https://github.com/NotAShelf/direnv.nvim";
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version=branch" ];
  };
  strictDeps = true;
}
