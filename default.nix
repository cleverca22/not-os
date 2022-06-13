{ configuration ? import ./configuration.nix, nixpkgs ? <nixpkgs>, extraModules ? [], system ? builtins.currentSystem, platform ? null }:

let
  pkgs = import nixpkgs { inherit system; platform = platform; config = {}; };
  pkgsModule = rec {
    _file = ./default.nix;
    key = _file;
    config = {
      nixpkgs.localSystem = { inherit system; };
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
    { _module.check = true; }
  ];
  evalConfig = modules: pkgs.lib.evalModules {
    prefix = [];
    modules = modules ++ baseModules ++ [ pkgsModule ] ++ extraModules;
  };
in
rec {
  test1 = evalConfig [
    configuration
  ];
  runner = test1.config.system.build.runvm;
  config = test1.config;
}
