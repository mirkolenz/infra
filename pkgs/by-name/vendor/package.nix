{ mkPythonApp, gitMinimal }:
# Configurations select their checkouts through `withConfig`, e.g. `pkgs.vendor.withConfig { ... }`.
mkPythonApp {
  script = "vendor";
  description = "Replace the vendored copies of checkouts in the current project";
  runtimeInputs = [ gitMinimal ];
}
