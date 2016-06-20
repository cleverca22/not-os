{ supportedSystems ? [ "x86_64-linux" "i686-linux" ] }:

with import <nixpkgs/lib>;

let
  pkgs = import <nixpkgs> { config = {}; };
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
  fetchClosure = f: forAllSystems (system: f (import ./default.nix { inherit system; }).config );
in
{
  tests.boot = callSubTests tests/boot.nix {};
  closureSizes = {
    toplevel = fetchClosure (cfg: cfg.system.build.toplevel);
    initialRamdisk = fetchClosure (cfg: cfg.system.build.initialRamdisk);
    squashed = fetchClosure (cfg: cfg.system.build.squashfs);
  };
  dist_test = fetchClosure (cfg: pkgs.runCommand "dist" { inherit (cfg.system.build) dist; }''
    #!/bin/sh
    mkdir -p $out/nix-support
    echo file kernel ''${dist}/kernel > $out/nix-support/hydra-build-products
    echo file rootfs ''${dist}/root.squashfs >> $out/nix-support/hydra-build-products
    echo file initrd ''${dist}/initrd >> $out/nix-support/hydra-build-products
    echo file command-line ''${dist}/command-line >> $out/nix-support/hydra-build-products
  '');
}
