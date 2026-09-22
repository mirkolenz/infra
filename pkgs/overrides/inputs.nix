final: prev:
# Packages from flake inputs, built against this package set. A flake's own
# `packages` would import a private nixpkgs, so only overlays and package files
# are used, and only the attributes named here are taken from each overlay.
let
  inherit (prev) lib;
  inherit (final) inputs;
  fromOverlay = overlay: names: lib.getAttrs names (overlay final prev);

  disko = final.callPackage "${inputs.disko}/package.nix" {
    diskoVersion = (import "${inputs.disko}/version.nix").version;
  };

  vicinae = inputs.vicinae.overlays.default final prev;
  # the upstream overlay takes numen from numen's own package set
  numen = (inputs.vicinae.inputs.numen.overlays.default final prev).numen.override {
    withRepl = false;
  };

  # mirrors the vicinae-extensions flake's own `packages`
  # https://github.com/vicinaehq/extensions/blob/main/flake.nix
  mkCommunityExtension =
    name:
    final.mkVicinaeExtension {
      pname = "vicinae-extension-${name}";
      version = "0";
      src = "${inputs.vicinae-extensions}/extensions/${name}";
      npmFlags = [ "--legacy-peer-deps" ];
      postPatch = ''
        substituteInPlace tsconfig.json --replace "../../" "${inputs.vicinae-extensions}/"
      '';
    };
in
fromOverlay inputs.makejinja.overlays.default [ "makejinja" ]
// fromOverlay inputs.neovim-nightly-overlay.overlays.default [ "neovim-unwrapped" ]
// fromOverlay inputs.opnix.overlays.default [ "opnix" ]
// {
  inherit disko;
  disko-install = disko.overrideAttrs { name = "disko-install"; };

  inherit (vicinae) mkVicinaeExtension;
  vicinae = lib.dontDistribute (vicinae.vicinae.override { inherit numen; });
  vicinaeExtensions = lib.genAttrs [
    "github"
    "nix"
  ] mkCommunityExtension;
}
