{ caddy }:
caddy.withPlugins {
  plugins = [
    # https://github.com/caddy-dns/cloudflare/tags
    "github.com/caddy-dns/cloudflare@v0.2.4"
  ];
  hash = "sha256-5a5cpFl90pEWt0lUC4ZJQ7g+1//ZvsRhee64Dt9vh5o=";
}
