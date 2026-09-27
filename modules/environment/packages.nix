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
          encrypt.text = /* bash */ ''
            # @describe Encrypt a file for a GnuPG recipient
            # @arg source-path!
            # @arg target-path!
            # @arg recipient!    Key of the recipient

            exec ${gpg} --output "$argc_target_path" --encrypt --recipient "$argc_recipient" "$argc_source_path"
          '';
          decrypt.text = /* bash */ ''
            # @describe Decrypt a GnuPG encrypted file
            # @arg source-path!
            # @arg target-path!

            exec ${gpg} --output "$argc_target_path" --decrypt "$argc_source_path"
          '';
          backup.text = /* bash */ ''
            # @describe Archive a path as root into a timestamped tarball
            # @arg source-path!
            # @arg target-dir!

            mkdir -p "$argc_target_dir"
            timestamp=$(date +"%Y-%m-%d-%H-%M-%S")
            sudo ${tar} -czf "$argc_target_dir/$timestamp.tgz" "$argc_source_path"
          '';
          restore.text = /* bash */ ''
            # @describe Extract a tarball as root
            # @arg source-path!
            # @arg target-dir!

            mkdir -p "$argc_target_dir"
            sudo ${tar} -xzf "$argc_source_path" -C "$argc_target_dir"
          '';
          compress.text = /* bash */ ''
            # @describe Archive a path into a tarball next to it
            # @arg source-path!
            # @arg tar-args~     Further arguments of tar

            exec ${tar} -czf "$argc_source_path.tgz" "$argc_source_path" "''${argc_tar_args[@]}"
          '';
          decompress.text = /* bash */ ''
            # @describe Extract a tarball into the working directory
            # @arg source-path!
            # @arg tar-args~     Further arguments of tar

            exec ${tar} -xzf "$argc_source_path" "''${argc_tar_args[@]}"
          '';
          noeol.text = /* bash */ ''
            # @describe Remove the newlines from stdin

            exec tr -d '\n'
          '';
          json-tool.text = /* bash */ ''
            # @describe Validate and pretty-print JSON
            # @arg args~ Arguments of python -m json.tool

            exec ${python} -m json.tool "$@"
          '';
          http-server.text = /* bash */ ''
            # @describe Serve the working directory over HTTP
            # @arg args~ Arguments of python -m http.server

            exec ${python} -m http.server "$@"
          '';
          wget-mirror.text = /* bash */ ''
            # @describe Mirror a website politely
            # @arg args~ Arguments of wget

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
