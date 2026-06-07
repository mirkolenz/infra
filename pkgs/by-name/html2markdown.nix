{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
  nix-update-script,
}:
buildGoModule (finalAttrs: {
  pname = "html2markdown";
  version = "2.5.2";

  src = fetchFromGitHub {
    owner = "JohannesKaufmann";
    repo = "html-to-markdown";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Ay2ICo+zhVDLX8fpAfc+8/YrLGRCD9swDjAQHiA9+Eg=";
  };

  vendorHash = "sha256-/7Rm01pzjIZ31wxH5mjqGpojFX5GZknjRnFKPrr4JF4=";

  subPackages = [ "./cli/html2markdown" ];

  ldflags = [
    "-s"
    "-X=main.version=${finalAttrs.version}"
    "-X=main.commit=${finalAttrs.src.rev}"
    "-X=main.date=1970-01-01T00:00:00Z"
  ];

  passthru.updateScript = nix-update-script { };

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";
  doInstallCheck = true;

  strictDeps = true;
  __structuredAttrs = true;

  meta = {
    description = "Convert HTML to Markdown. Even works with entire websites and can be extended through rules";
    homepage = "https://github.com/JohannesKaufmann/html-to-markdown";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "html2markdown";
  };
})
