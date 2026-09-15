{
  lib,
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}:
vimUtils.buildVimPlugin {
  pname = "flexoki";
  version = "0-unstable-2025-08-26";
  src = fetchFromGitHub {
    owner = "kepano";
    repo = "flexoki-neovim";
    rev = "c3e2251e813d29d885a7cbbe9808a7af234d845d";
    hash = "sha256-TlBP99MBAT/H0Uut1MF8SnIDoeetcdHLKrWal2oO2Ug=";
  };
  meta = {
    homepage = "https://github.com/kepano/flexoki-neovim";
    maintainers = with lib.maintainers; [ mirkolenz ];
  };
  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version=branch" ];
  };
  strictDeps = true;
}
