{ pkgs, config, ... }:
let
  modules = pkgs.makeModulesClosure {
    rootModules = config.boot.initrd.availableKernelModules ++ config.boot.initrd.kernelModules;
    allowMissing = true;
    kernel = config.system.build.kernel;
  };
  bootStage1 = pkgs.writeScript "stage1" ''
    #!${pkgs.stdenv.shell}
    echo
    echo "[1;32m<<< NotOS Stage 1 >>>[0m"
    echo

    export PATH=${pkgs.busybox}/bin/
    mkdir -p /proc /sys /dev /etc/udev /tmp /run/ /lib/ /mnt/
    mount -t devtmpfs devtmpfs /dev/
    mount -t proc proc /proc

    ln -s ${modules}/lib/modules /lib/modules

    modprobe virtio
    modprobe virtio_pci
    modprobe virtio_net
    modprobe virtio_rng

    modprobe virtio_blk
    modprobe virtio_console
    modprobe squashfs
    modprobe tun
    modprobe loop
    
    root=/dev/vda
    for o in $(cat /proc/cmdline); do
      case $o in
        systemConfig=*)
          set -- $(IFS==; echo $o)
          sysconfig=$2
          ;;
        root=*)
          set -- $(IFS==; echo $o)
          root=$2
          ;;
      esac
    done
    mount -t tmpfs root /mnt/
    chmod 755 /mnt/
    mkdir -p /mnt/nix/store/
    
    mount $root /mnt/nix/store/ -t squashfs

    exec env -i $(type -P switch_root) /mnt/ $sysconfig/init
    exec ${pkgs.stdenv.shell}
  '';
  initialRamdisk = pkgs.makeInitrd {
    contents = [ { object = bootStage1; symlink = "/init"; } ];
  };
in
{
  config = {
    system.build.bootStage1 = bootStage1;
    system.build.initialRamdisk = initialRamdisk;
    boot.initrd.availableKernelModules = [ "squashfs" "virtio" "virtio_pci" "virtio_blk" "virtio_net" "tun" "virtio-rng" "loop" ];
  };
}
