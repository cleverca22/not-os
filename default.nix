{ configuration ? import ./configuration.nix }:

with import <nixpkgs> {};

rec {
  pkgsModule = rec {
    _file = ./default.nix;
    key = _file;
    config = {
      nixpkgs.system = lib.mkDefault builtins.currentSystem;
    };
  };
  test1 = lib.evalModules {
    prefix = [];
    check = true;
    modules = [
      configuration
      ./base.nix
      ./system-path.nix
      ./stage-1.nix
      ./stage-2.nix
      ./runit.nix
      pkgsModule
      <nixpkgs/nixos/modules/system/etc/etc.nix>
      <nixpkgs/nixos/modules/system/activation/activation-script.nix>
      <nixpkgs/nixos/modules/misc/nixpkgs.nix>
    ];
    args = {};
  };
  runner = test1.config.system.build.runvm;
}
