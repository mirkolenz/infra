# The repository formatter, evaluated with the features of the host,
# so that the hosts with little memory leave out the formatters they would have to build.
{
  lib,
  pkgs,
  config,
  ...
}:
{
  options.custom.treefmt = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    internal = true;
    default = pkgs.treefmt-nix.override { inherit (config.custom) features; };
    defaultText = lib.literalExpression "pkgs.treefmt-nix.override { inherit (config.custom) features; }";
    description = "The repository formatter, with the formatters of the languages enabled on this host.";
  };
}
