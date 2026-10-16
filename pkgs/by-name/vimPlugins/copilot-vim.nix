{
  lib,
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}:
vimUtils.buildVimPlugin rec {
  pname = "copilot.vim";
  version = "1.59.0";
  src = fetchFromGitHub {
    owner = "github";
    repo = "copilot.vim";
    tag = "v${version}";
    hash = "sha256-McrihGscbvt2lqHil3NxHUfgx/IAFDf7tdbBkv4vTK4=";
  };
  meta = {
    homepage = "https://github.com/github/copilot.vim";
    maintainers = with lib.maintainers; [ mirkolenz ];
    # a plain copy of the source, cheaper to refetch than to cache
    hydraPlatforms = [ ];
  };
  passthru.updateScript = nix-update-script { };
  strictDeps = true;
}
