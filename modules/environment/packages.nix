{
  flake.modules.homeManager.default =
    { pkgs, lib, ... }:
    let
      gpg = lib.getExe pkgs.gnupg;
      tar = lib.getExe pkgs.gnutar;
      pigz = lib.getExe pkgs.pigz;
    in
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
        # http clients and servers
        httpie
        xh
        miniserve
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
      custom.commands = {
        gpgfile.text = /* bash */ ''
          # @describe Encrypt and decrypt files with GnuPG

          # @cmd Encrypt a file
          # @option -r --recipient*  Key of a recipient, which GnuPG asks for if absent
          # @arg source-path!
          # @arg target-path         Encrypted file, defaulting to the source with a .gpg extension
          encrypt() {
            exec ${gpg} --output "''${argc_target_path:-$argc_source_path.gpg}" --encrypt "''${argc_recipient[@]/#/--recipient=}" "$argc_source_path"
          }

          # @cmd Decrypt a file
          # @arg source-path!
          # @arg target-path  Decrypted file, defaulting to the source without its .gpg extension
          decrypt() {
            exec ${gpg} --output "''${argc_target_path:-''${argc_source_path%.gpg}}" --decrypt "$argc_source_path"
          }
        '';
        tgz.text = /* bash */ ''
          # @describe Create and extract gzipped tarballs
          # @meta inherit-flag-options
          # @flag -s --sudo  Run tar as root

          # @cmd Archive a path into a tarball
          # @option -o --output <FILE>  Tarball to create, defaulting to the source with a .tgz extension
          # @arg source-path!
          # @arg tar-args~              Further arguments of tar
          create() {
            ''${argc_sudo:+sudo} ${tar} -c -I ${pigz} -f "''${argc_output:-''${argc_source_path%/}.tgz}" "''${argc_tar_args[@]}" "$argc_source_path"
          }

          # @cmd Extract a tarball
          # @option -C --directory=.  Directory receiving the contents
          # @arg source-path!
          # @arg tar-args~            Further arguments of tar
          extract() {
            ''${argc_sudo:+sudo} mkdir -p "$argc_directory"
            ''${argc_sudo:+sudo} ${tar} -x -I ${pigz} -f "$argc_source_path" -C "$argc_directory" "''${argc_tar_args[@]}"
          }
        '';
        noeol.text = /* bash */ ''
          # @describe Remove the newlines from stdin

          exec tr -d '\n'
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
