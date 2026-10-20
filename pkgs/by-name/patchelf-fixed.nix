# patchelf with unmerged fixes for large prebuilt binaries such as claude-code and semgrep-core.
# Drop it once nixpkgs' patchelf includes both pull requests.
# Only `src/` is taken, since both also edit `tests/Makefile.am` and conflict there.
{ patchelf, fetchpatch }:
patchelf.overrideAttrs (prevAttrs: {
  patches = prevAttrs.patches or [ ] ++ [
    # DT_VERDEF keeps pointing to the old `.gnu.version_d` after it was relocated
    # https://github.com/NixOS/patchelf/pull/665
    (fetchpatch {
      url = "https://github.com/NixOS/patchelf/commit/52fd21df79d6631799db20b17c2d23121e1eb176.patch";
      includes = [ "src/*" ];
      hash = "sha256-4Z7TyktsTkl1eDNS9JUErpBMaVZsJ+kvEDNAa6AVZ5Y=";
    })
    # growing both interpreter and rpath produces overlapping LOAD mappings,
    # which leaves claude-code silent and aborts semgrep-core with `splitIndex == -1`
    # https://github.com/NixOS/patchelf/pull/672
    (fetchpatch {
      url = "https://github.com/NixOS/patchelf/commit/59acc3d98b4961cfddf02090d9426ac735603218.patch";
      includes = [ "src/*" ];
      hash = "sha256-rQWWZlCa4IRrcPcxMD2xrTTD4nLOsWfdZLOk9UoIOIs=";
    })
  ];
})
