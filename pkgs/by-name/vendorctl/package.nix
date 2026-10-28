{ mkPythonApp, gitMinimal }:
# Configurations select their checkouts through `withConfig`, e.g. `pkgs.vendorctl.withConfig { ... }`.
mkPythonApp {
  script = "vendorctl";
  description = "Replace the vendored copies of checkouts in the current project";
  runtimeInputs = [ gitMinimal ];
}
