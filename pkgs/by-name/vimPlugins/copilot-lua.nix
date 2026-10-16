{
  lib,
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}:
vimUtils.buildVimPlugin rec {
  pname = "copilot.lua";
  version = "3.1.14";
  src = fetchFromGitHub {
    owner = "zbirenbaum";
    repo = "copilot.lua";
    tag = "v${version}";
    hash = "sha256-o1gZ2+gJdvxq07USm5hCGj/NVm1edVjEDDiVew0jQfg=";
  };
  meta = {
    homepage = "https://github.com/zbirenbaum/copilot.lua";
    maintainers = with lib.maintainers; [ mirkolenz ];
  };
  passthru.updateScript = nix-update-script { };
  strictDeps = true;
}
