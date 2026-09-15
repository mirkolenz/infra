{
  lib,
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}:
vimUtils.buildVimPlugin {
  pname = "direnv.nvim";
  version = "0-unstable-2026-06-28";
  src = fetchFromGitHub {
    owner = "NotAShelf";
    repo = "direnv.nvim";
    rev = "9258f9f10c4c729d8296fce0e3ecb12543daad06";
    hash = "sha256-b5PpmkYWaDGLNcu+36tRR5ycATHYBjs9WrV8/jfmooQ=";
  };
  meta = {
    homepage = "https://github.com/NotAShelf/direnv.nvim";
    maintainers = with lib.maintainers; [ mirkolenz ];
  };
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version=branch" ];
  };
  strictDeps = true;
}
