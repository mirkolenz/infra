{
  lib,
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}:
vimUtils.buildVimPlugin rec {
  pname = "copilot.lua";
  version = "3.2.4";
  src = fetchFromGitHub {
    owner = "zbirenbaum";
    repo = "copilot.lua";
    tag = "v${version}";
    hash = "sha256-GIX1mOzsGWsSWLoUBFsTcaQv3zEM1BRhEfBYFq9YsoE=";
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
