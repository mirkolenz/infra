# SSH across all classes: shared known hosts (nixos + darwin), the OpenSSH
# server hardening per platform, and the user's client config and forwarded agent (home-manager).
let
  # update: ssh-keyscan -t ed25519 URL_OR_IP
  knownHosts = {
    "github.com".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    "gitlab.com".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf";
    "gitlab.rlp.net".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMqZhJQejjLLmvCk0wEgSDN5+6oCgp3ggKw0MBl5VDXI";
    "eu.nixbuild.net".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
    "gpu.wi2.uni-trier.de".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFjEIHTnzAhYtFJhcXrWm7OuzWli/YUNMsq9xmlEjUfE";
    "macpro.taildc4a8b.ts.net".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP5n2KpAU3E8iHy56vNURjh7E3l0EjkZ6BX450Z44hiH";
    "raspi.taildc4a8b.ts.net".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGR8BCsN02425GzSv1PQNhUGx0rm8D4aKSZh8ut5OJ6/";
    "raise.dfki.de".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM1nnFyFYCUDMUQzia4jzpaFcSURq4Dn7Tkr4QUBd1ti";
  };
in
{
  flake.modules.nixos.base =
    { config, lib, ... }:
    {
      programs.ssh = { inherit knownHosts; };
      security.pam = lib.mkIf config.services.openssh.enable {
        rssh.enable = true;
        services.sudo.rssh = true;
      };
      programs.mosh = {
        enable = false;
        openFirewall = true;
      };
      services.eternal-terminal.enable = false;
      services.openssh = {
        enable = lib.mkDefault true;
        authorizedKeysInHomedir = false;
        openFirewall = true;
        settings = {
          # reap dead clients so their forwarded agent sockets vanish
          ClientAliveInterval = 30;
          KbdInteractiveAuthentication = false;
          PasswordAuthentication = false;
          PermitRootLogin = "no";
          X11Forwarding = false;
        };
        hostKeys = [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };
    };

  flake.modules.darwin.base =
    { lib, pkgs, ... }:
    {
      programs.ssh = { inherit knownHosts; };
      # nixos rssh counterpart tried before Touch ID,
      # the stock macOS sudoers already keeps SSH_AUTH_SOCK
      security.pam.services.sudo_local.text = lib.mkBefore ''
        auth       sufficient     ${pkgs.pam_rssh}/lib/libpam_rssh.dylib auth_key_file=/etc/ssh/nix_authorized_keys.d/$ruser
      '';
      programs.mosh.enable = false;
      services.eternal-terminal.enable = false;
      services.openssh = {
        enable = true;
        extraConfig = ''
          ClientAliveInterval 30
          KbdInteractiveAuthentication no
          PasswordAuthentication no
          PermitRootLogin no
          X11Forwarding no
        '';
      };
    };

  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      # forwarded agent of the newest ssh login, stable across reconnects
      agentLink = "${config.home.homeDirectory}/.ssh/ssh_auth_sock";
    in
    {
      home.file.".ssh/rc".text = ''
        if [ -S "$SSH_AUTH_SOCK" ]; then
          ln -sf "$SSH_AUTH_SOCK" ${agentLink}
        fi
      '';
      home.sessionVariables.SSH_AUTH_SOCK = agentLink;
      custom.commands =
        let
          ssh = lib.getExe pkgs.openssh;
        in
        {
          # Discarding the known hosts file makes ssh announce the host key as
          # newly added on every run, so drop anything below an error.
          ssh-once.text = /* bash */ ''
            # @describe Connect with ssh without checking or remembering the host key
            # @arg args~ Arguments of ssh

            exec ${ssh} -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -o "LogLevel=ERROR" "$@"
          '';
          nixbuild-shell.text = /* bash */ ''
            # @describe Open the nixbuild.net shell

            exec ${lib.getExe pkgs.rlwrap} ${ssh} eu.nixbuild.net shell
          '';
        };
      programs.ssh = lib.mkIf config.custom.features.graphical.enable {
        enable = true;
        enableDefaultConfig = false;
        includes = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin [
          "${config.home.homeDirectory}/.orbstack/ssh/config"
        ];
        settings = {
          # prefer a live forwarded agent over the IdentityAgent of `*` (1Password)
          "Match exec 'test -S ${agentLink}'".IdentityAgent = agentLink;
          "*" = {
            # default config from home manager module
            ForwardAgent = false;
            Compression = false;
            ServerAliveInterval = 0;
            ServerAliveCountMax = 3;
            HashKnownHosts = false;
            UserKnownHostsFile = "~/.ssh/known_hosts";
          };
          "gpu" = {
            HostName = "gpu.wi2.uni-trier.de";
            ForwardAgent = true;
            User = "lenz";
          };
          "kitei" = {
            HostName = "kitei-gpu.wi2.uni-trier.de";
            User = "compute";
          };
          "raise" = {
            HostName = "raise.dfki.de";
            ForwardAgent = true;
            User = "mlenz";
          };
          "macpro homeserver" = {
            HostName = "macpro.taildc4a8b.ts.net";
            ForwardAgent = true;
            User = "mlenz";
          };
          "raspi" = {
            HostName = "raspi.taildc4a8b.ts.net";
            ForwardAgent = true;
            User = "mlenz";
          };
        };
      };
    };
}
