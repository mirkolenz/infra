final: prev:
# Packages nixpkgs builds from linux sources or marks linux-only that do work on darwin.
# These are ports we carry until upstream takes them, not bugs waiting on a release, so
# unlike `hotfixes.nix` they have no fix to track and are expected to live here for a
# long time. Each one says what it does and what would let it go.
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {

  # libvirt.dylib is linked with -Wl,-flat_namespace, so its libxml2 imports bind to the system
  # /usr/lib/libxml2.2.dylib that every CPython process maps. There xmlSchemaInitTypes() returns
  # void instead of int, so libvirt reads an uninitialized register and fails schema validation
  # at random. A failure also leaks the shared test:///default state into
  # testDomainIDReturnsValidValue.
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (
      _: pyprev:
      {
        libvirt-python = pyprev.libvirt-python.overridePythonAttrs (prevAttrs: {
          disabledTests = (prevAttrs.disabledTests or [ ]) ++ [ "testCheckpointCreate" ];
        });

        # licomp-toolkit is marked badPlatforms over licomp-oslc-handbook#4, where
        # `licenses/` and `LICENSES/` collide on a case-insensitive filesystem. That
        # collision only merges the yaml the matrix is generated from with the REUSE
        # license texts, and neither is read at runtime: the handbook ships its matrix as
        # a committed json that the darwin build reproduces byte for byte, so the marker
        # is stale rather than load bearing. Without this, sbom-compliance-tool is
        # unavailable on darwin too.
        # https://github.com/hesa/licomp-oslc-handbook/issues/4
        licomp-toolkit = pyprev.licomp-toolkit.overridePythonAttrs (prevAttrs: {
          meta = prevAttrs.meta // {
            badPlatforms = [ ];
          };
        });

        # nixpkgs disabled this pure python dependency on darwin in a 2022 treewide sweep
        # that marked 120 packages at once (65db3b17). Its memory test assumes linux
        # ru_maxrss units and writes hundreds of gigabytes on macos.
        # todo: send upstream, then drop this once nixpkgs unmarks it
        jsonstreams = pyprev.jsonstreams.overridePythonAttrs (prevAttrs: {
          doInstallCheck = false;
          meta = prevAttrs.meta // {
            broken = false;
          };
        });
      }
      # nixpkgs builds scancode's three native plugins from the linux variants of the
      # upstream sources, which makes every consumer of the toolkit linux-only. The macos
      # variants of the same release expect exactly the dylibs nixpkgs already ships.
      # These live here rather than beside `scancode-toolkit`, since `lookup-license` and
      # `sbom-compliance-tool` reach the same plugins independently.
      # todo: send upstream, then drop this once nixpkgs builds the plugins on darwin
      //
        prev.lib.mapAttrs
          (
            name: preBuild:
            pyprev.${name}.overridePythonAttrs (prevAttrs: {
              sourceRoot = (prev.lib.removeSuffix "-linux" prevAttrs.sourceRoot) + "-macosx";
              inherit preBuild;

              meta = prevAttrs.meta // {
                platforms = prev.lib.platforms.darwin;
              };
            })
          )
          {
            # only the executable is looked up, the codec library beside it is deprecated and unused
            extractcode-7z = ''
              pushd src/extractcode_7z/bin
              rm 7z 7z.so
              ln -s ${prev.lib.getExe' final.p7zip "7z"} 7z
              popd
            '';

            extractcode-libarchive = ''
              pushd src/extractcode_libarchive/lib
              rm *.dylib
              ln -s ${prev.lib.getLib final.libarchive}/lib/libarchive.dylib libarchive.dylib
              ln -s ${prev.lib.getLib final.libb2}/lib/libb2.1.dylib libb2.1.dylib
              ln -s ${prev.lib.getLib final.lz4}/lib/liblz4.1.dylib liblz4.1.dylib
              ln -s ${prev.lib.getLib final.xz}/lib/liblzma.5.dylib liblzma.5.dylib
              ln -s ${prev.lib.getLib final.zstd}/lib/libzstd.1.dylib libzstd.1.dylib
              popd
            '';

            typecode-libmagic = ''
              pushd src/typecode_libmagic
              rm data/magic.mgc lib/libmagic.dylib
              ln -s ${final.file}/share/misc/magic.mgc data/magic.mgc
              ln -s ${prev.lib.getLib final.file}/lib/libmagic.dylib lib/libmagic.dylib
              popd
            '';
          }
    )
  ];
}
