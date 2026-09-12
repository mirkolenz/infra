{
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}:
vimUtils.buildVimPlugin rec {
  pname = "copilot.lua";
  version = "3.1.7";
  src = fetchFromGitHub {
    owner = "zbirenbaum";
    repo = "copilot.lua";
    rev = "v${version}";
    hash = "sha256-RYi+Ofn+kqXkw8z2f1avH62MMLqVyIIDJaYBCMt/fBw=";
  };
  meta.homepage = "https://github.com/zbirenbaum/copilot.lua/";
  passthru.updateScript = nix-update-script { };
  strictDeps = true;
}
