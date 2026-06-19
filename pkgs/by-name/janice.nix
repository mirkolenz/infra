{
  buildGoModule,
  fetchFromGitHub,
  fyne,
  lib,
  nix-update-script,
}:
buildGoModule (finalAttrs: {
  pname = "janice";
  version = "0.10.0";

  src = fetchFromGitHub {
    owner = "ErikKalkoken";
    repo = "janice";
    tag = "v${finalAttrs.version}";
    hash = "sha256-GkzxjsUkPw0hccsnxCLdr2D+AvFTdQ7+O4r9F0bUths=";
  };

  vendorHash = "sha256-rNL3eMWaT+Q+NoutUDvD9Gs9SM0B6s95P88ynsRp1GQ=";

  subPackages = [ "." ];

  ldflags = [ "-s" ];

  inherit (fyne) buildInputs nativeBuildInputs;

  passthru.updateScript = nix-update-script { };

  strictDeps = true;
  __structuredAttrs = true;

  meta = {
    description = "A desktop app for viewing large JSON files";
    homepage = "https://github.com/ErikKalkoken/janice";
    changelog = "https://github.com/ErikKalkoken/janice/releases";
    downloadPage = "https://github.com/ErikKalkoken/janice/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "janice";
  };
})
