{
  flake.modules.homeManager.default =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        tree
        moreutils
        gnupg
        gnumake
        recutils
        inetutils
        gcc
        zip
        unzip
        lsd
        fd
        procs
        sd
        bandwhich
        delta
        fzf
        rsync
        wget
        ookla-speedtest
        restic
        autorestic
        sqlite
        icloudpd
        rlwrap
        wol
        stress-ng
        fuc
        # json parsing
        jq
        jaq
        jql
        yq
        dasel
        # http requests
        httpie
        xh
        # bulk renaming
        massren
        mmv-go
        pipe-rename
        edir
        # disk usage
        gdu
        dua
        ncdu
        duf
        # required packages: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/system-path.nix
        # acl # not available on darwin
        # attr # not available on darwin
        bashInteractive # bash with ncurses support
        bzip2
        coreutils-full
        cpio
        curl
        diffutils
        findutils
        gawk
        stdenv.cc.libc
        getent
        getconf
        gnugrep
        gnused
        gzip
        xz
        # libcap # not available on darwin
        # ncurses # conflict with ghostty terminfo
        netcat
        mkpasswd
        procps
        # su # not available on darwin
        time
        util-linux
        which
        zstd
      ];
    };
}
