{
  lib,
  mkZellijPlugin,
  fetchFromGitHub,
  nix-update-script,
}:
mkZellijPlugin (finalAttrs: {
  pname = "zellij-choose-tree";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "laperlej";
    repo = "zellij-choose-tree";
    tag = "v${finalAttrs.version}";
    hash = "sha256-NEhE+h5RXZd/KtIMv6K+QfKNXhRx47Oe1Ld44XeA5dU=";
  };

  cargoHash = "sha256-BNFm72A5PLzY6AxXsTjNiVGkKAIL40g1nZ0DJ9GkWDo=";

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Zellij plugin to quickly switch between sessions";
    homepage = "https://github.com/laperlej/zellij-choose-tree";
    changelog = "https://github.com/laperlej/zellij-choose-tree/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
  };
})
