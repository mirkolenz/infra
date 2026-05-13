{
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}:
vimUtils.buildVimPlugin rec {
  pname = "copilot.lua";
  version = "2.0.3";
  src = fetchFromGitHub {
    owner = "zbirenbaum";
    repo = "copilot.lua";
    rev = "v${version}";
    hash = "sha256-sYcKs46PF+j9wvP+UQ+asGUNgZHD5JLnq9KQOube0mA=";
  };
  meta.homepage = "https://github.com/zbirenbaum/copilot.lua/";
  passthru.updateScript = nix-update-script { };
  strictDeps = true;
}
