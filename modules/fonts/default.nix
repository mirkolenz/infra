let
  fonts =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.withDisplay {
      fonts.packages =
        with pkgs;
        [
          font-awesome
          lucide
          material-design-icons
          nerd-fonts.symbols-only
        ]
        ++ (lib.optionals stdenv.hostPlatform.isLinux [
          # keep-sorted start
          cascadia-code
          eb-garamond
          fira-code
          fira-mono
          fira-sans
          geist-font
          ia-writer-duospace
          ia-writer-mono
          ia-writer-quattro
          ibm-plex
          intel-one-mono
          inter
          iosevka
          jetbrains-mono
          jost
          maple-mono.NF-unhinted
          maple-mono.truetype
          monaspace
          nerd-fonts.blex-mono
          nerd-fonts.caskaydia-cove
          nerd-fonts.fira-code
          nerd-fonts.intone-mono
          nerd-fonts.jetbrains-mono
          nerd-fonts.monaspace
          nerd-fonts.ubuntu
          nerd-fonts.ubuntu-mono
          nerd-fonts.ubuntu-sans
          roboto
          roboto-flex
          roboto-mono
          roboto-serif
          roboto-slab
          source-code-pro
          source-sans
          source-serif
          tangerine
          tex-gyre-math.bonum
          tex-gyre-math.pagella
          tex-gyre-math.schola
          tex-gyre-math.termes
          tex-gyre.adventor
          tex-gyre.bonum
          tex-gyre.chorus
          tex-gyre.cursor
          tex-gyre.heros
          tex-gyre.pagella
          tex-gyre.schola
          tex-gyre.termes
          ubuntu-classic
          ubuntu-sans
          ubuntu-sans-mono
          # keep-sorted end
        ]);
    };
in
{
  flake.modules.nixos.base = fonts;
  flake.modules.darwin.base = fonts;
}
