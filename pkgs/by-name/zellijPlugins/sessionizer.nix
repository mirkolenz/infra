{
  lib,
  mkZellijPlugin,
  fetchFromGitHub,
  nix-update-script,
}:
mkZellijPlugin (finalAttrs: {
  pname = "zellij-sessionizer";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "laperlej";
    repo = "zellij-sessionizer";
    tag = "v${finalAttrs.version}";
    hash = "sha256-uCUoafvtDY62eqUH9d9HEAAqQ0/q6glivcYQyYx5T5w=";
  };

  cargoHash = "sha256-txSzHKGeAScRFwx1RzlNT0oscEw+5hLcCpb3N5ke4yo=";

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Zellij plugin to quickly switch to project sessions";
    homepage = "https://github.com/laperlej/zellij-sessionizer";
    license = lib.licenses.mit;
  };
})
