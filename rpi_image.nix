{ config, pkgs, ... }:

{
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
    cp -s ${config.system.build.kernel}/*zImage kernel7.img
    cp -s ${config.system.build.squashfs} root.squashfs
    cp ${firm}/boot/bcm2710-rpi-3-b.dtb bcm2710-rpi-3-b.dtb
    cp -r ${firm}/boot/overlays overlays
    cp -s ${firm}/boot/start.elf start.elf
    cp ${firm}/boot/fixup.dat fixup.dat
    cp -s ${config.system.build.initialRamdisk}/initrd initrd
    ls -ltrhL
  '';
  environment.systemPackages = [ pkgs.strace ];
  nixpkgs.config.packageOverrides = pkgs: {
    linux_rpi = pkgs.callPackage ./linux-rpi.nix {};
  };
  nixpkgs.overlays = [
    (self: super: {
      libuv = super.libuv.overrideAttrs (old: {
        doCheck = false;
      });
      elfutils = super.elfutils.overrideAttrs (old: {
        doCheck = false;
        doInstallCheck = false;
      });
      systemd = super.systemd.overrideAttrs (old: {
        withEfi = false;
      });
    })
  ];
}
