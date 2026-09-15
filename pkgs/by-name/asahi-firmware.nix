{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  python3,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "asahi-firmware";
  version = "0.9.1";

  src = fetchFromGitHub {
    owner = "AsahiLinux";
    repo = "asahi-installer";
    tag = "v${finalAttrs.version}";
    hash = "sha256-IbGH5pn65XL7tIbvwYLk1GLjjnp7wI1DV/4e94cySCc=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # Both modules already write a tarball of renamed firmware when run as
  # scripts; bluetooth.py just imports FWPackage from the package root, which
  # the shipped empty __init__ does not re-export.
  postPatch = ''
    echo 'from .core import FWFile, FWPackage' > asahi_firmware/__init__.py
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/${python3.sitePackages}"
    cp -r asahi_firmware "$out/${python3.sitePackages}/"

    for kind in wifi bluetooth; do
      makeWrapper ${lib.getExe python3} "$out/bin/get-$kind" \
        --add-flags "-m asahi_firmware.$kind" \
        --prefix PYTHONPATH : "$out/${python3.sitePackages}"
    done

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  strictDeps = true;
  __structuredAttrs = true;

  meta = {
    description = "Asahi Linux scripts that rename Apple's Broadcom firmware for brcmfmac and hci_bcm4377";
    homepage = "https://github.com/AsahiLinux/asahi-installer";
    # upstream tags its versions but publishes no releases, so there is nothing to link a changelog to
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
    # Only ever used on a T2 Mac, so keep it out of CI.
    hydraPlatforms = [ ];
  };
})
