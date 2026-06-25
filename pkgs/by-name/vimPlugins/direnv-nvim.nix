{
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}:
vimUtils.buildVimPlugin {
  pname = "direnv.nvim";
  version = "0-unstable-2026-06-24";
  src = fetchFromGitHub {
    owner = "NotAShelf";
    repo = "direnv.nvim";
    rev = "b41d16d88de2753059827e030d4dabcdb8deeec2";
    hash = "sha256-gWOe2NjmWf1LPWgHgSJqMkaq9As+XA/pTPJT04WZMCA=";
  };
  meta.homepage = "https://github.com/NotAShelf/direnv.nvim";
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version=branch" ];
  };
  strictDeps = true;
}
