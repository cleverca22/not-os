{ configuration ? import ./configuration.nix
, pkgs ? import <nixpkgs> {
    inherit system;
    platform = platform;
    config = {};
 }
, extraModules ? []
, system ? builtins.currentSystem
, platform ? null
, crossSystem ? null
}: let
  inherit (import ./eval-config.nix {
    nixpkgs = pkgs;
    inherit extraModules;
  }) evalModules;
in rec {
  test1 = evalModules {
    modules = [configuration];
  };
  runner = test1.config.system.build.runvm;
  config = test1.config;
}
