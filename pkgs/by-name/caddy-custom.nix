{ nixpkgs }:
nixpkgs.caddy.withPlugins {
  plugins = [
    # https://github.com/caddy-dns/cloudflare/tags
    "github.com/caddy-dns/cloudflare@v0.2.4"
  ];
  hash = "sha256-7GoH8YLCoPmPExQxoga2FHB58zQDoZVf1BBwkVi0SsQ=";
}
