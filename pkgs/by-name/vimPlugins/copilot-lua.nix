{
  lib,
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}:
vimUtils.buildVimPlugin rec {
  pname = "copilot.lua";
  version = "3.1.11";
  src = fetchFromGitHub {
    owner = "zbirenbaum";
    repo = "copilot.lua";
    tag = "v${version}";
    hash = "sha256-EwiQt71RuOrF334rxMb0YoejfYALqrkH88kcJWYBX1U=";
  };
  meta = {
    homepage = "https://github.com/zbirenbaum/copilot.lua";
    maintainers = with lib.maintainers; [ mirkolenz ];
  };
  passthru.updateScript = nix-update-script { };
  strictDeps = true;
}
