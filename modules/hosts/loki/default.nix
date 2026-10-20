# ODBC clients for the SAP SQL Anywhere 17 driver,
# installed imperatively to its default directory and kept unmodified for licensing reasons.
{
  configurations.home."mlenz@loki".module =
    { pkgs, lib, ... }:
    let
      sqlanywhere = "/opt/sqlanywhere17";
      socat = lib.getExe pkgs.socat;
    in
    {
      # No network access except for a TCP tunnel from 127.0.0.1:2638 to the database server,
      # read from ~/.config/sqlanywhere/target as host:port to keep it out of this public repo,
      # so the DSNs of ~/.odbc.ini need `Host=127.0.0.1`,
      # and `RetryConnTO=5` to wait for the listener within the sandbox to start.
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
          # the directory, since the tunnel creates its socket asynchronously
          ''--ro-bind "$dir" /run/sqlanywhere''
        ];
        init = ''
          ${socat} TCP-LISTEN:2638,bind=127.0.0.1,fork UNIX-CONNECT:/run/sqlanywhere/socket &

          # The driver finds its own libraries only through LD_LIBRARY_PATH,
          # since Nix's glibc ignores the ldconfig cache of the host,
          # and the C++ runtime of the host is not in the sandbox.
          export LD_LIBRARY_PATH=${sqlanywhere}/lib64:${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}
        '';
      };
    };
}
