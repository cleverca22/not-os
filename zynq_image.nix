{ config, pkgs, ... }:

let
  # dont use overlays for the qemu, it causes a lot of wasted time on recompiles
  x86pkgs = import pkgs.path { system = "x86_64-linux"; };
  customKernel = pkgs.linux.override {
    extraConfig = ''
      OVERLAY_FS y
    '';
  };
  customKernelPackages = pkgs.linuxPackagesFor customKernel;
in {
  imports = [ ./arm32-cross-fixes.nix ];
  boot.kernelPackages = customKernelPackages;
  nixpkgs.system = "armv7l-linux";
  system.build.zynq_image = let
    cmdline = "root=/dev/mmcblk0 console=ttyPS0,115200n8 systemConfig=${builtins.unsafeDiscardStringContext config.system.build.toplevel}";
    qemuScript = ''
      #!/bin/bash -v
      export PATH=${x86pkgs.qemu}/bin:$PATH
      set -x
      base=$(dirname $0)

      cp $base/root.squashfs /tmp/
      chmod +w /tmp/root.squashfs
      truncate -s 64m /tmp/root.squashfs

      qemu-system-arm \
        -M xilinx-zynq-a9 \
        -serial /dev/null \
        -serial stdio \
        -display none \
        -dtb $base/zynq-zc702.dtb \
        -kernel $base/zImage \
        -initrd $base/initrd \
        -drive file=/tmp/root.squashfs,if=sd,format=raw \
        -append "${cmdline}"
    '';
  in pkgs.runCommand "zynq_image" {
    inherit qemuScript;
    passAsFile = [ "qemuScript" ];
    preferLocalBuild = true;
  } ''
    mkdir $out
    cd $out
    cp -s ${config.system.build.squashfs} root.squashfs
    cp -s ${config.system.build.kernel}/*zImage .
    cp -s ${config.system.build.initialRamdisk}/initrd initrd
    cp -s ${config.system.build.kernel}/dtbs/zynq-zc702.dtb .
    ln -sv ${config.system.build.toplevel} toplevel
    cp $qemuScriptPath qemu-script
    chmod +x qemu-script
    patchShebangs qemu-script
    ls -ltrh
  '';
  system.build.rpi_image_tar = pkgs.runCommand "dist.tar" {} ''
    mkdir -p $out/nix-support
    tar -cvf $out/dist.tar ${config.system.build.rpi_image}
    echo "file binary-dist $out/dist.tar" >> $out/nix-support/hydra-build-products
  '';
  environment.systemPackages = [ pkgs.strace ];
  environment.etc."service/getty/run".source = pkgs.writeShellScript "getty" ''
    agetty ttyPS0 115200
  '';
  environment.etc."pam.d/other".text = "";
}
