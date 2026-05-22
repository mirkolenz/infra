{ nixpkgs }:
nixpkgs.caddy.withPlugins {
  plugins = [
    # https://github.com/caddy-dns/cloudflare/tags
    "github.com/caddy-dns/cloudflare@v0.2.4"
  ];
  hash = "sha256-bzMqxWTqrJ1skZmRTXyEMCKStXpljbqe5r0Ve2cnBfM=";
}
