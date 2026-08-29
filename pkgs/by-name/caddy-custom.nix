# Deliberately the pinned `nixpkgs` instance rather than the shared package set:
# `pkgsFor` is nixos-unstable on linux but nixpkgs-unstable on darwin, and the
# single `hash` below is only valid for one caddy version.
# For a package whose hash does not depend on its build inputs, importing the
# pinned file into the shared set is the cheaper pattern:
#   pkgs.callPackage "${inputs.nixpkgs}/pkgs/by-name/ca/caddy/package.nix" { }
{ nixpkgs }:
nixpkgs.caddy.withPlugins {
  plugins = [
    # https://github.com/caddy-dns/cloudflare/tags
    "github.com/caddy-dns/cloudflare@v0.2.4"
  ];
  hash = "sha256-dQvk6ezY6TQ1J7PjhCXnThF/SqVgPwBO8/RXzHCY+js=";
}
