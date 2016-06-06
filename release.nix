{ supportedSystems ? [ "x86_64-linux" "i686-linux" ] }:

with import <nixpkgs/lib>;

let
  forAllSystems = genAttrs supportedSystems;
  importTest = fn: args: system: import fn ({
    inherit system;
  } // args);
  callTest = fn: args: forAllSystems (system: hydraJob (importTest fn args system));
  callSubTests = fn: args: let
    discover = attrs: let
      subTests = filterAttrs (const (hasAttr "test")) attrs;
    in mapAttrs (const (t: hydraJob t.test)) subTests;

    discoverForSystem = system: mapAttrs (_: test: {
      ${system} = test;
    }) (discover (importTest fn args system));
  # If the test is only for a particular system, use only the specified
  # system instead of generating attributes for all available systems.
  in if args ? system then discover (import fn args)
     else foldAttrs mergeAttrs {} (map discoverForSystem supportedSystems);
in
{
  tests.boot = callSubTests tests/boot.nix {};
}
