{ configuration ? import ./configuration.nix, nixpkgs ? <nixpkgs>, extraModules ? [], system ? builtins.currentSystem }:

let
  pkgs = import nixpkgs { inherit system; config = {}; };
  baseModules = [
      ./base.nix
      ./system-path.nix
      ./stage-1.nix
      ./stage-2.nix
      ./runit.nix
      (nixpkgs + "/nixos/modules/system/etc/etc.nix")
      (nixpkgs + "/nixos/modules/system/activation/activation-script.nix")
      (nixpkgs + "/nixos/modules/misc/nixpkgs.nix")
      <nixpkgs/nixos/modules/system/boot/kernel.nix>
      <nixpkgs/nixos/modules/misc/assertions.nix>
      <nixpkgs/nixos/modules/misc/lib.nix>
      <nixpkgs/nixos/modules/config/sysctl.nix>
  ];
in
rec {
  pkgsModule = rec {
    _file = ./default.nix;
    key = _file;
    config = {
      nixpkgs.system = pkgs.lib.mkDefault system;
    };
  };
  test1 = pkgs.lib.evalModules {
    prefix = [];
    check = true;
    modules = [
      configuration
      ./ipxe.nix
      ./systemd-compat.nix
      pkgsModule
    ] ++ extraModules ++ baseModules;
    args = {};
  };
  runner = test1.config.system.build.runvm;
  config = test1.config;
}
