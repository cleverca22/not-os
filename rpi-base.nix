{ config, lib, pkgs, ... }:

let
in {
  options = {
    rpi.rpi1 = lib.mkEnableOption "support pi1";
    rpi.rpi2 = lib.mkEnableOption "support pi2";
    rpi.rpi3 = lib.mkEnableOption "support pi3";
    rpi.rpi4 = lib.mkEnableOption "support pi4";
    rpi.rpi5 = lib.mkEnableOption "support pi5";
    rpi.copyKernels = lib.mkOption {
      type = lib.types.separatedString "\n";
    };
  };
  config = lib.mkMerge [
    (lib.mkIf config.rpi.rpi1 {
      rpi.copyKernels = ''
        cp ${pkgs.linuxPackages_rpi1}/zImage kernel.img
      '';
    })
    (lib.mkIf config.rpi.rpi2 {
      rpi.copyKernels = ''
        cp ${pkgs.linuxPackages_rpi2}/zImage kernel7.img
      '';
    })
  ];
}
