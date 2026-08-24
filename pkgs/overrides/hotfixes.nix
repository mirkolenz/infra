final: prev:
{ }
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
})
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  # https://github.com/NixOS/nixpkgs/pull/555604
  tmux = prev.tmux.overrideAttrs (prevAttrs: {
    buildInputs = prevAttrs.buildInputs ++ [ prev.jemalloc ];
    configureFlags = prevAttrs.configureFlags ++ [ "--enable-jemalloc" ];
  });
})
