{ nixpkgs
, baseModules ? import ./module-list.nix
, extraModules ? []
}:
let
  nixos-lib = import (nixpkgs + /nixos/lib) {
    featureFlags.minimalModules = true;
  };

  modulesModule = {
    config = {
      _module.args = {
        inherit baseModules extraModules;
      };
    };
  };

  evalModules = {modules}: nixos-lib.evalModules {
    prefix = [];
    specialArgs = {
      notOSmodulesPath = builtins.toString ./.;
    };
    modules = modules ++ baseModules ++ extraModules ++ [
      modulesModule
    ];
  };

  /* This specifies the testing node type which governs the
  module system that is applied to each node.

  In our case, it needs to be the not os module set.

  It also consumes the defaults set for all nodes as well as,
  by convention of the nixos testing framework, node wise
  specialArgs.

  We ignore config.extraBaseModules, however:
  use extraModules, instead.
 
  */
  nodeType = {config, hostPkgs, ...}: {
    node.type = (nixos-lib.evalModules {
      prefix = [];
      specialArgs = {
        notOSmodulesPath = builtins.toString ./.;
      } // config.node.specialArgs;
      modules = [config.defaults] ++ baseModules ++ extraModules ++ [
        modulesModule
        ./tests/test-instrumentation.nix
      ];
    }).type;
  };

  evalTest = module: nixos-lib.evalTest {
    imports = [
      module
      nodeType
    ];
  };
  runTest = module: nixos-lib.runTest {
    imports = [
      module
      nodeType
    ];
  };
in {
  inherit evalModules evalTest runTest;
}
