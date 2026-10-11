# Shared nixos + darwin base: timezone, default shells, 1password/opnix.
let
  shared =
    { lib, pkgs, ... }:
    {
      time.timeZone = "Europe/Berlin";
      environment = {
        defaultPackages = lib.mkForce [ ];
        systemPackages = [ pkgs.opnix ];
      };
      programs = {
        _1password.enable = true;
        bash.enable = true;
        fish.enable = true;
        zsh.enable = true;
      };
    };

  # The GitHub tokens of nix and the sandboxed agents, rendered from 1Password on the machines
  # that enable opnix, outside of outputDir, which darwin keeps untraversable for the users.
  # nix fetches flakes in the client, so the admins read its access tokens.
  opnix =
    { config, pkgs, ... }:
    let
      dir = dirOf config.services.onepassword-secrets.outputDir;
    in
    {
      services.onepassword-secrets.secrets = {
        nixAccessTokens = {
          reference = "op://NixOS/GitHub/nix-conf";
          path = "${dir}/nix/secrets.conf";
          group = if pkgs.stdenv.hostPlatform.isDarwin then "admin" else "wheel";
          mode = "0640";
        };
        agentsGithubToken = {
          reference = "op://NixOS/GitHub/credential";
          path = "${dir}/agents/github-token";
          owner = config.custom.user.login;
          mode = "0400";
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
      # the opnix script does not pass the strict checks of `core/linux.nix`
      systemd.services.opnix-secrets = lib.mkIf config.services.onepassword-secrets.enable {
        enableStrictShellChecks = false;
      };
    };

  flake.modules.darwin.base.imports = [
    shared
    opnix
  ];

  # the opnix service account token, which reads the whole vault, and the access tokens of nix
  flake.modules.homeManager.default =
    { lib, lib', ... }@args:
    let
      opnix = lib'.osOpnix args;
    in
    lib.mkIf opnix.enable {
      programs.agents.sandbox.paths = {
        ${opnix.tokenFile} = "deny";
        ${opnix.secretPaths.nixAccessTokens} = "deny";
      };
    };
}
