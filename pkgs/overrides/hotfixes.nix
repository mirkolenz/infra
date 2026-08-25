final: prev:
{ }
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
})
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  # nodejs 26 hangs in test-dgram-udp6-link-local-address, so build the webui with nodejs 24
  # https://hydra.nixos.org/job/nixpkgs/unstable/nodejs_26.aarch64-darwin
  llama-cpp = prev.llama-cpp.override {
    nodejs_latest = prev.nodejs;
  };

  # the pty-driven shell completion tests of cyclopts capture garbage instead of completions
  # https://hydra.nixos.org/job/nixpkgs/unstable/python314Packages.cyclopts.aarch64-darwin
  mcp-nixos = prev.mcp-nixos.override {
    python3Packages = final.python3Packages.overrideScope (
      _: pyPrev: {
        cyclopts = pyPrev.cyclopts.overridePythonAttrs (prevAttrs: {
          disabledTestPaths = (prevAttrs.disabledTestPaths or [ ]) ++ [ "tests/completion" ];
        });
      }
    );
  };
})
