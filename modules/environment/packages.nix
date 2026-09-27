{
  flake.modules.homeManager.default =
    { pkgs, lib, ... }:
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
      custom.commands =
        let
          gpg = lib.getExe pkgs.gnupg;
          python = lib.getExe pkgs.python3;
          tar = lib.getExe pkgs.gnutar;
        in
        {
          encrypt = /* bash */ ''
            if [ "$#" -ne 3 ]; then
              echo "Usage: $0 SOURCE TARGET RECIPIENT" >&2
              exit 1
            fi

            exec ${gpg} --output "$2" --encrypt --recipient "$3" "$1"
          '';
          decrypt = /* bash */ ''
            if [ "$#" -ne 2 ]; then
              echo "Usage: $0 SOURCE TARGET" >&2
              exit 1
            fi

            exec ${gpg} --output "$2" --decrypt "$1"
          '';
          backup = /* bash */ ''
            if [ "$#" -ne 2 ]; then
              echo "Usage: $0 SOURCE_PATH TARGET_DIR" >&2
              exit 1
            fi
            mkdir -p "$2"
            TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")
            sudo ${tar} -czf "$2/$TIMESTAMP.tgz" "$1"
          '';
          restore = /* bash */ ''
            if [ "$#" -ne 2 ]; then
              echo "Usage: $0 SOURCE_PATH TARGET_DIR" >&2
              exit 1
            fi
            mkdir -p "$2"
            sudo ${tar} -xzf "$1" -C "$2"
          '';
          compress = /* bash */ ''
            if [ "$#" -lt 1 ]; then
              echo "Usage: $0 SOURCE_PATH [TAR_ARGS...]" >&2
              exit 1
            fi
            source_path="$1"
            shift

            exec ${tar} -czf "$source_path.tgz" "$source_path" "$@"
          '';
          decompress = /* bash */ ''
            if [ "$#" -lt 1 ]; then
              echo "Usage: $0 SOURCE_PATH [TAR_ARGS...]" >&2
              exit 1
            fi
            source_path="$1"
            shift

            exec ${tar} -xzf "$source_path" "$@"
          '';
          noeol = /* bash */ ''
            exec tr -d '\n'
          '';
          json-tool = /* bash */ ''
            exec ${python} -m json.tool "$@"
          '';
          http-server = /* bash */ ''
            exec ${python} -m http.server "$@"
          '';
          wget-mirror = /* bash */ ''
            exec ${lib.getExe pkgs.wget} \
              --mirror \
              --convert-links \
              --adjust-extension \
              --page-requisites \
              --no-parent \
              --wait=1 \
              --random-wait \
              --user-agent="Mozilla/5.0" \
              "$@"
          '';
        };
    };
}
