{ config, pkgs, ... }:

{
  imports = [ ./arm32-cross-fixes.nix ];
  nixpkgs.system = "armv7l-linux";
  system.build.rpi_image = let
    config_txt = pkgs.writeText "config.txt" ''
      initramfs initrd followkernel
      dtoverlay=pi3-disable-bt
      enable_uart=1
    '';
    cmdline = pkgs.writeText "cmdline.txt" ''
      console=ttyS0,115200 pi3-disable-bt kgdboc=ttyS0,115200 systemConfig=${builtins.unsafeDiscardStringContext config.system.build.toplevel} netroot=192.168.2.1=9080d9b6/root.squashfs quiet splash plymouth.ignore-serial-consoles plymouth.ignore-udev
    '';
    firm = config.system.build.rpi_firmware;
  in pkgs.runCommand "rpi_image" {} ''
    mkdir $out
    cd $out
    cp ${config_txt} config.txt
    cp ${cmdline} cmdline.txt
    cp ${config.system.build.kernel}/*zImage kernel7.img
    cp ${config.system.build.squashfs} root.squashfs
    cp ${firm}/boot/bcm2710-rpi-3-b.dtb bcm2710-rpi-3-b.dtb
    cp -r ${firm}/boot/overlays overlays
    cp ${firm}/boot/start.elf start.elf
    cp ${firm}/boot/fixup.dat fixup.dat
    cp ${config.system.build.initialRamdisk}/initrd initrd
    ls -ltrhL
  '';
  system.build.rpi_image_tar = pkgs.runCommand "dist.tar" {} ''
    mkdir -p $out/nix-support
    tar -cvf $out/dist.tar ${config.system.build.rpi_image}
    echo "file binary-dist $out/dist.tar" >> $out/nix-support/hydra-build-products
  '';
  environment.systemPackages = [ pkgs.strace ];
  nixpkgs.config.packageOverrides = pkgs: {
    linux_rpi = pkgs.callPackage ./linux-rpi.nix {};
  };
}
