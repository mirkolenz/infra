# Shared nixos + darwin base: timezone, default shells, 1password/opnix.
let
  shared =
    { lib, pkgs, ... }:
    {
      time.timeZone = lib.mkDefault "Europe/Berlin";
      environment = {
        defaultPackages = lib.mkForce [ ];
        systemPackages = [ pkgs.opnix ];
      };
      programs = {
        _1password = {
          enable = true;
          package = pkgs._1password-cli-bin;
        };
        bash.enable = true;
        fish.enable = true;
        zsh.enable = true;
      };
    };

  # The GitHub tokens of nix and the sandboxed agents, rendered from 1Password
  # outside of outputDir, which darwin keeps untraversable for the users.
  # nix fetches flakes in the client, so the admins read its access tokens.
  # opnix renders nothing until `opnix token set` provisions the host.
  opnix =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.onepassword-secrets;
      dir = dirOf cfg.outputDir;
      token = cfg.placeholder.githubToken;
    in
    {
      services.onepassword-secrets = {
        enable = lib.mkDefault true;
        secrets.githubToken = {
          reference = "op://NixOS/GitHub/credential";
          path = "${dir}/github-token";
          mode = "0400";
        };
        templates.nixSecrets = {
          path = "${dir}/nix/secrets.conf";
          group = if pkgs.stdenv.hostPlatform.isDarwin then "admin" else "wheel";
          mode = "0640";
          content = ''
            access-tokens = github.com=${token}
            impure-env = NIX_GITHUB_PRIVATE_USERNAME=x-access-token NIX_GITHUB_PRIVATE_PASSWORD=${token}
          '';
        };
      };
    };
in
{
  flake.modules.nixos.base =
    { config, lib, ... }:
    {
      imports = [
        shared
        opnix
      ];
      # fish generates man page completions at runtime instead, see `programs/shells.nix`
      programs.fish.generateCompletions = false;

      # the opnix script does not pass the strict checks of `core/linux.nix`
      systemd.services.opnix-secrets = lib.mkIf config.services.onepassword-secrets.enable {
        enableStrictShellChecks = false;
      };
    };

  flake.modules.darwin.base.imports = [
    shared
    opnix
  ];
}
