{
  configurations.home."mlenz@loki".module =
    { pkgs, lib, ... }:
    let
      sqlanywhere = "/opt/sqlanywhere17";
      socat = lib.getExe pkgs.socat;
    in
    {
      custom.bubblewrap.sqlanywhere = {
        packages = with pkgs; [
          usql
          harlequin
          unixodbc
        ];
        setup = ''
          target=$(<~/.config/sqlanywhere/target)
          dir=$(mktemp -d)
          ${socat} UNIX-LISTEN:"$dir/socket",fork TCP:"$target" &
          trap 'kill $!; rm -rf "$dir"' EXIT
        '';
        args = [
          "--setenv SQLANY17 ${sqlanywhere}"
          "--ro-bind ${sqlanywhere} ${sqlanywhere}"
          "--ro-bind /etc/odbcinst.ini /etc/odbcinst.ini"
          "--ro-bind ~/.odbc.ini ~/.odbc.ini"
          ''--ro-bind "$dir" /run/sqlanywhere''
        ];
        init = ''
          ${socat} TCP-LISTEN:2638,bind=127.0.0.1,fork UNIX-CONNECT:/run/sqlanywhere/socket &

          export LD_LIBRARY_PATH=${sqlanywhere}/lib64:${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}
        '';
      };
    };
}
