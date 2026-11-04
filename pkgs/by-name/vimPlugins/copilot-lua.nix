{
  lib,
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}:
vimUtils.buildVimPlugin rec {
  pname = "copilot.lua";
  version = "3.2.2";
  src = fetchFromGitHub {
    owner = "zbirenbaum";
    repo = "copilot.lua";
    tag = "v${version}";
    hash = "sha256-4AwzZRziOB0I6+ckBhf0DY1f6bpshPI1ennU6x52ROA=";
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
