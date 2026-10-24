{ caddy, go }:
(caddy.withPlugins {
  plugins = [
    # https://github.com/caddy-dns/cloudflare/tags
    "github.com/caddy-dns/cloudflare@v0.2.4"
  ];
  hash = "sha256-tubXIDCJnO2mvdnPlZclwDhNGaeeYLSt7lnni3+pXDo=";
}).overrideAttrs
  (prevAttrs: {
    # Like buildGoModule's `goSum`, the go version in the name forces a rebuild on go bumps,
    # since xcaddy records it in `go.mod` and `fix hashes` only sees rebuilt mismatches.
    src = prevAttrs.src.overrideAttrs { pname = "${prevAttrs.src.pname}-go${go.version}"; };
  })
