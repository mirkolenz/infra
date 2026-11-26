{
  lib,
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}:
vimUtils.buildVimPlugin rec {
  pname = "copilot.lua";
  version = "3.2.7";
  src = fetchFromGitHub {
    owner = "zbirenbaum";
    repo = "copilot.lua";
    tag = "v${version}";
    hash = "sha256-nHoURCjFVs2Y7uWJaXvuXzCOw9hxYuH1E0lR3zwbo+Q=";
  };
  meta = {
    homepage = "https://github.com/zbirenbaum/copilot.lua";
    maintainers = with lib.maintainers; [ mirkolenz ];
    # a plain copy of the source, cheaper to refetch than to cache
    hydraPlatforms = [ ];
  };
  passthru.updateScript = nix-update-script { };
  strictDeps = true;
}
