let
  # nono reads the token as the user before starting the sandbox.
  tokenOwner =
    { config, lib, ... }:
    {
      services.onepassword-secrets.secrets.githubToken.owner =
        lib.mkIf config.custom.features.agents.enable config.custom.user.login;
    };
in
{
  flake.modules.darwin.base = tokenOwner;
  flake.modules.nixos.base = tokenOwner;

  flake.modules.homeManager.default =
    { config, lib, ... }@args:
    let
      opnix = args.osConfig.services.onepassword-secrets or { enable = false; };
    in
    lib.mkIf config.programs.agents.enable {
      programs.agents.sandbox = lib.mkIf opnix.enable {
        # Also cover secrets rendered outside outputDir and future ones added there.
        paths.deny = lib.unique (
          [
            opnix.tokenFile
            opnix.outputDir
          ]
          ++ lib.attrValues opnix.secretPaths
          ++ lib.attrValues opnix.templatePaths
        );
        environment.files.GITHUB_TOKEN = opnix.secretPaths.githubToken;
        # Nix fetches GitHub inputs in the client, using the same agent token as gh.
        environment.templates.NIX_CONFIG = "access-tokens = github.com=$GITHUB_TOKEN";
      };
      # The tokens of the host, also without injected ones.
      # Only nono strips them, the native sandboxes of the harnesses would drop the injected ones.
      programs.nono.profiles.agents.environment.deny_vars = [
        "GH_TOKEN"
        "GITHUB_TOKEN"
        "NIX_CONFIG"
      ];
    };
}
