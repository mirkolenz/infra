{
  pkgs,
  lib,
  config,
  ...
}:
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
    tealdeer
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
    ast-grep
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
    # nix
    nixpkgs-review
    nix-eval-jobs
    nix-output-monitor
    nix-fast-build
    fh
    nh
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
    less
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
  home.shellAliases = {
    cat = lib.getExe config.programs.bat.package;
    lg = lib.getExe config.programs.lazygit.package;
    lw = lib.getExe config.programs.lazyworktree.package;
    py = "${lib.getExe config.programs.uv.package} run";
  };
}
