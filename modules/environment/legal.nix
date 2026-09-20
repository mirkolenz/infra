# Clients for the official legal corpora, one per jurisdiction, reading the consolidated
# text rather than a mirror. The guidance around them ships as pdf, which `poppler-utils`
# in `optionals.nix` reads.
{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      home.packages = with pkgs; [
        # EU law
        eurlex
        # German federal law from gesetze-im-internet.de:
        # `recht list`, `recht list <abbr>`, `recht get <abbr> <norm>`
        recht
      ];
    };
}
