{
  lib,
  stdenv,
  python3Packages,
  file,
  libarchive,
  libb2,
  lz4,
  p7zip,
  xz,
  zstd,
}:
let
  pythonPackages = python3Packages.overrideScope (
    _: prev:
    lib.optionalAttrs stdenv.hostPlatform.isDarwin (
      # nixpkgs builds the three native plugins from the linux variants of the upstream sources,
      # which makes the whole toolkit linux-only; the macos variants of the same release expect
      # exactly the dylibs that nixpkgs already ships
      # todo: send upstream, then drop this once nixpkgs builds the plugins on darwin
      lib.mapAttrs
        (
          name: preBuild:
          prev.${name}.overrideAttrs (old: {
            sourceRoot = lib.removeSuffix "-linux" old.sourceRoot + "-macosx";
            inherit preBuild;

            meta = old.meta // {
              platforms = lib.platforms.darwin;
            };
          })
        )
        {
          # only the executable is looked up, the codec library beside it is deprecated and unused
          extractcode-7z = ''
            pushd src/extractcode_7z/bin
            rm 7z 7z.so
            ln -s ${lib.getExe' p7zip "7z"} 7z
            popd
          '';

          extractcode-libarchive = ''
            pushd src/extractcode_libarchive/lib
            rm *.dylib
            ln -s ${lib.getLib libarchive}/lib/libarchive.dylib libarchive.dylib
            ln -s ${lib.getLib libb2}/lib/libb2.1.dylib libb2.1.dylib
            ln -s ${lib.getLib lz4}/lib/liblz4.1.dylib liblz4.1.dylib
            ln -s ${lib.getLib xz}/lib/liblzma.5.dylib liblzma.5.dylib
            ln -s ${lib.getLib zstd}/lib/libzstd.1.dylib libzstd.1.dylib
            popd
          '';

          typecode-libmagic = ''
            pushd src/typecode_libmagic
            rm data/magic.mgc lib/libmagic.dylib
            ln -s ${file}/share/misc/magic.mgc data/magic.mgc
            ln -s ${lib.getLib file}/lib/libmagic.dylib lib/libmagic.dylib
            popd
          '';
        }
      // {
        # nixpkgs disabled this pure python dependency on darwin in a 2022 treewide sweep that
        # marked 120 packages at once (65db3b17); its own test suite passes there today
        # todo: send upstream, then drop this once nixpkgs unmarks it
        jsonstreams = lib.addMetaAttrs { broken = false; } prev.jsonstreams;
      }
    )
  );
in
(pythonPackages.toPythonApplication pythonPackages.scancode-toolkit).overrideAttrs (old: {
  meta = old.meta // {
    mainProgram = "scancode";
    maintainers = old.meta.maintainers ++ [ lib.maintainers.mirkolenz ];
  };
})
