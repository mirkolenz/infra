{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
  nix-update-script,
}:
buildGoModule (finalAttrs: {
  pname = "html2markdown";
  version = "2.5.1";

  src = fetchFromGitHub {
    owner = "JohannesKaufmann";
    repo = "html-to-markdown";
    tag = "v${finalAttrs.version}";
    hash = "sha256-SFN1rXlJdkNu0xq6MzW3TGMo1HGfFtU/7kMfkEkKFEQ=";
  };

  vendorHash = "sha256-JWusYN482+ei2kqiGYnAVfBGbdfThu8LHBX3JhMU6FE=";

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
