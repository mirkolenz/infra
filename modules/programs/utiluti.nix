{
  flake.modules.homeManager.darwin =
    { lib, ... }:
    let
      # assigns the app to all handlers of each kind, e.g. `{ types = [ ... ]; }`
      forApp = app: lib.mapAttrs (_: handlers: lib.genAttrs handlers (_: app));
    in
    {
      # Type identifiers come from `utiluti get-uti <ext>`, which covers all extensions of a type.
      # Abstract supertypes such as `public.image` are omitted since files never resolve to them.
      programs.utiluti = lib.mkMerge [
        { enable = true; }
        (forApp "dev.zed.Zed" {
          types = [
            "com.apple.log"
            "com.microsoft.ini"
            "com.microsoft.typescript"
            "com.netscape.javascript-source"
            "com.sun.java-source"
            "net.daringfireball.markdown"
            "org.iso.sql"
            "public.bash-script"
            "public.c-plus-plus-source"
            "public.c-source"
            "public.comma-separated-values-text"
            "public.css"
            "public.json"
            "public.make-source"
            "public.objective-c-source"
            "public.plain-text"
            "public.python-script"
            "public.ruby-script"
            "public.shell-script"
            "public.swift-source"
            "public.toml"
            "public.xml"
            "public.yaml"
            "public.zsh-script"
          ];
          extensions = [
            "astro"
            "bib"
            "cjs"
            "cls"
            "conf"
            "fish"
            "go"
            "graphql"
            "jsx"
            "lock"
            "lua"
            "mdx"
            "nix"
            "pyi"
            "rs"
            "scss"
            "sty"
            "svelte"
            "tex"
            "typ"
            "vue"
          ];
        })
        (forApp "com.wolfrosch.Gapplin" { types = [ "public.svg-image" ]; })
        (forApp "com.readdle.PDFExpert-Mac" { types = [ "com.adobe.pdf" ]; })
        (forApp "com.apple.TextEdit" { types = [ "public.rtf" ]; })
        (forApp "com.apple.iBooksX" { types = [ "org.idpf.epub-container" ]; })
        (forApp "com.apple.Preview" {
          types = [
            "com.compuserve.gif"
            "org.webmproject.webp"
            "public.avif"
            "public.heic"
            "public.jpeg"
            "public.png"
            "public.tiff"
          ];
        })
        (forApp "com.apple.QuickTimePlayerX" {
          types = [
            # audio
            "com.apple.m4a-audio"
            "com.microsoft.waveform-audio"
            "org.xiph.flac"
            "public.aac-audio"
            "public.mp3"
            # video
            "com.apple.m4v-video"
            "com.apple.quicktime-movie"
            "public.mpeg-4"
          ];
        })
        (forApp "com.aone.keka" {
          types = [
            "com.rarlab.rar-archive"
            "org.7-zip.7-zip-archive"
            "org.gnu.gnu-zip-archive"
            "org.gnu.gnu-zip-tar-archive"
            "org.tukaani.xz-archive"
            "public.bzip2-archive"
            "public.tar-archive"
            "public.zip-archive"
          ];
        })
        (forApp "com.mitchellh.ghostty" { types = [ "public.unix-executable" ]; })
        (forApp "org.mozilla.firefox" { schemes = [ "http" ]; })
        (forApp "ch.sudo.cyberduck" { schemes = [ "sftp" ]; })
        (forApp "com.apple.mail" { schemes = [ "mailto" ]; })
        (forApp "com.apple.FaceTime" { schemes = [ "tel" ]; })
        (forApp "com.apple.iCal" { schemes = [ "webcal" ]; })
      ];
    };
}
