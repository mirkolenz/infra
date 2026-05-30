{ ... }:
{
  programs.infat = {
    enable = true;
    autoActivate = false; # todo: broken as of 2026-03-19
    settings = {
      extensions = {
        # Programming
        astro = "Zed";
        bash = "Zed";
        bib = "Zed";
        cjs = "Zed";
        cls = "Zed";
        conf = "Zed";
        cfg = "Zed";
        css = "Zed";
        csv = "Zed";
        env = "Zed";
        fish = "Zed";
        go = "Zed";
        gql = "Zed";
        graphql = "Zed";
        ini = "Zed";
        java = "Zed";
        js = "Zed";
        json = "Zed";
        jsx = "Zed";
        less = "Zed";
        lock = "Zed";
        log = "Zed";
        lua = "Zed";
        md = "Zed";
        mdx = "Zed";
        mjs = "Zed";
        nix = "Zed";
        py = "Zed";
        pyi = "Zed";
        rb = "Zed";
        rs = "Zed";
        sass = "Zed";
        scss = "Zed";
        sh = "Zed";
        sql = "Zed";
        sty = "Zed";
        svelte = "Zed";
        svg = "Gapplin";
        tex = "Zed";
        toml = "Zed";
        ts = "Zed";
        tsx = "Zed";
        txt = "Zed";
        typ = "Zed";
        vue = "Zed";
        xml = "Zed";
        yaml = "Zed";
        yml = "Zed";
        zsh = "Zed";
        # Documents
        pdf = "PDF Expert";
        rtf = "TextEdit";
        epub = "Books";
        # Images
        avif = "Preview";
        heic = "Preview";
        heif = "Preview";
        webp = "Preview";
        # Audio
        aac = "QuickTime Player";
        flac = "QuickTime Player";
        m4a = "QuickTime Player";
        mp3 = "QuickTime Player";
        ogg = "QuickTime Player";
        wav = "QuickTime Player";
        # Video
        avi = "QuickTime Player";
        m4v = "QuickTime Player";
        mkv = "QuickTime Player";
        mov = "QuickTime Player";
        mp4 = "QuickTime Player";
        webm = "QuickTime Player";
        # Archives
        "7z" = "Keka";
        bz2 = "Keka";
        gz = "Keka";
        rar = "Keka";
        tar = "Keka";
        tgz = "Keka";
        xz = "Keka";
        zip = "Keka";
      };
      # /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -dump URLSchemeBinding
      # https://en.wikipedia.org/wiki/List_of_URI_schemes
      # https falls back to http on macOS, html/htm are also set by http
      schemes = {
        ftp = "ForkLift";
        # http = "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app";
        http = "Vivaldi";
        mailto = "Mail";
        sftp = "ForkLift";
        ssh = "Ghostty";
        tel = "FaceTime";
        webcal = "Calendar";
      };
      # https://github.com/philocalyst/infat/blob/629052902869778fa0e6b188d2f3d7d334377dd9/infat-lib/src/uti.rs#L385
      types = {
        # Text types
        text = "Zed";
        plain-text = "Zed";
        json = "Zed";
        xml = "Zed";
        yaml = "Zed";
        markdown = "Zed";
        rtf = "TextEdit";
        csv = "Zed";
        # Image types
        image = "Preview";
        raw-image = "Preview";
        png = "Preview";
        jpeg = "Preview";
        gif = "Preview";
        tiff = "Preview";
        svg = "Preview";
        webp = "Preview";
        heic = "Preview";
        heif = "Preview";
        bmp = "Preview";
        # Audio types
        audio = "QuickTime Player";
        mp3 = "QuickTime Player";
        wav = "QuickTime Player";
        aiff = "QuickTime Player";
        midi = "QuickTime Player";
        mp4-audio = "QuickTime Player";
        # Video types
        video = "QuickTime Player";
        movie = "QuickTime Player";
        quicktime-movie = "QuickTime Player";
        mp4-movie = "QuickTime Player";
        mpeg = "QuickTime Player";
        avi = "QuickTime Player";
        mpeg2-video = "QuickTime Player";
        # mpeg2-transport-stream = "QuickTime Player"; # uti not valid
        # m3u-playlist = "QuickTime Player"; # uti not valid
        # Archive types
        archive = "Keka";
        zip = "Keka";
        gzip = "Keka";
        tar = "Keka";
        # Source code types
        sourcecode = "Zed";
        c-source = "Zed";
        cpp-source = "Zed";
        objc-source = "Zed";
        swift-source = "Zed";
        shell = "Zed";
        makefile = "Zed";
        javascript = "Zed";
        python-script = "Zed";
        # typescript = "Zed"; # todo: not yet released
        # System types
        executable = "Ghostty";
        unix-executable = "Ghostty";
        # data = "/System/Library/CoreServices/Finder.app";
        # directory = "/System/Library/CoreServices/Finder.app";
        # folder = "/System/Library/CoreServices/Finder.app";
        # symlink = "/System/Library/CoreServices/Finder.app";
        # app-bundle = "/System/Library/CoreServices/Finder.app";
      };
    };
  };
}
