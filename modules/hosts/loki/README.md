# loki

Ubuntu host running the ODBC clients `usql`, `harlequin`, and `isql` for the SAP SQL Anywhere 17 driver within a bubblewrap sandbox.
The driver is installed imperatively to `/opt/sqlanywhere17` and kept unmodified for licensing reasons.

## Host preparation

Ubuntu restricts unprivileged user namespaces through AppArmor, so the Nix `bwrap` needs a profile granting `userns`.
Otherwise, it fails with `bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`.
Since 24.04, Ubuntu already sets `dev.tty.legacy_tiocsti` to 0, which keeps the sandbox from injecting input into the shared terminal.

```bash
sudo tee /etc/apparmor.d/nix-bwrap <<'EOF'
abi <abi/4.0>,
include <tunables/global>

profile nix-bwrap /nix/store/*-bubblewrap-*/bin/bwrap flags=(unconfined) {
  userns,
}
EOF
sudo apparmor_parser -r /etc/apparmor.d/nix-bwrap
```

## Network

The sandbox has no network access except for a TCP tunnel from `127.0.0.1:2638` to the database server.
The server is read from `~/.config/sqlanywhere/target` as `host:port` to keep it out of this public repo.
Outside the sandbox, `socat` forwards a Unix socket to the server.
The sandbox gets the socket's directory instead of the socket itself, since the tunnel creates it asynchronously.
Within the sandbox, another `socat` listens on `127.0.0.1:2638` and forwards to the socket.

Thus, the DSNs of `~/.odbc.ini` need `Host=127.0.0.1`, and `RetryConnTO=5` to wait for the listener within the sandbox to start.

## Libraries

The driver finds its own libraries only through `LD_LIBRARY_PATH`, since Nix's glibc ignores the ldconfig cache of the host.
The C++ runtime of the host is not in the sandbox, so `LD_LIBRARY_PATH` includes the one from Nix as well.
