{ configuration ? import ./configuration.nix
, nixpkgs ? <nixpkgs>
, extraModules ? []
, system ? builtins.currentSystem
, platform ? null
, crossSystem ? null }:

let
  pkgs = import nixpkgs { inherit system; platform = platform; config = {}; };
  pkgsModule = {config, ... }: {
    _file = ./default.nix;
    key = ./default.nix;
    config = {
      nixpkgs.pkgs = (import nixpkgs {
        inherit system crossSystem;
        #crossSystem = (import <nixpkgs/lib>).systems.examples.aarch64-multiplatform;
        config = config.nixpkgs.config;
        overlays = config.nixpkgs.overlays;
      });
      nixpkgs.localSystem = {
        inherit system;
      } // pkgs.lib.optionalAttrs (crossSystem != null) {
        inherit crossSystem;
      };
    };
  };
  baseModules = [
      ./base.nix
      ./system-path.nix
      ./stage-1.nix
      ./stage-2.nix
      ./runit.nix
      (nixpkgs + "/nixos/modules/system/etc/etc.nix")
      (nixpkgs + "/nixos/modules/system/activation/activation-script.nix")
      (nixpkgs + "/nixos/modules/misc/nixpkgs.nix")
      (nixpkgs + "/nixos/modules/system/boot/kernel.nix")
      (nixpkgs + "/nixos/modules/misc/assertions.nix")
      (nixpkgs + "/nixos/modules/misc/lib.nix")
      (nixpkgs + "/nixos/modules/config/sysctl.nix")
      ./ipxe.nix
      ./systemd-compat.nix
      pkgsModule
  ];
  evalConfig = modules: pkgs.lib.evalModules {
    prefix = [];
    check = true;
    modules = modules ++ baseModules ++ [ pkgsModule ] ++ extraModules;
    args = {};
  };
in
rec {
  test1 = evalConfig [
    configuration
  ];
  runner = test1.config.system.build.runvm;
  config = test1.config;
}
