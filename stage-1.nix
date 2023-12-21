{ lib, pkgs, config, ... }:

with lib;
let
  modules = pkgs.makeModulesClosure {
    rootModules = config.boot.initrd.availableKernelModules ++ config.boot.initrd.kernelModules;
    allowMissing = true;
    kernel = config.system.build.kernel;
    firmware = config.hardware.firmware;
  };
  plymouth = (pkgs.plymouth.override {
    udev = null;
    gtk3 = null;
    systemd = null;
  }).overrideDerivation (old: {
    #src = /tmp/plymouth;
    src = pkgs.fetchgit {
      url = "https://anongit.freedesktop.org/git/plymouth";
      rev = "266d954b7a0ff5b046df6ed54c22e3322b2c80d0";
      sha256 = "10k7vfbfp3q1ysw3w5nd6wnixizbng3lqbb21bgd18v997k74xb3";
    };
    #patches2 = [ ./fix2.patch ./udev3.patch ];
  });
  dhcpcd = pkgs.dhcpcd.override { udev = null; };
  extraUtils = pkgs.runCommandCC "extra-utils"
  {
    nativeBuildInputs = [ pkgs.nukeReferences ];
    allowedReferences = [ "out" ];
  } ''
    set +o pipefail
    mkdir -p $out/bin $out/lib
    ln -s $out/bin $out/sbin

    copy_bin_and_libs() {
      [ -f "$out/bin/$(basename $1)" ] && rm "$out/bin/$(basename $1)"
      cp -pd $1 $out/bin
    }

    # Copy Busybox
    for BIN in ${pkgs.busybox}/{s,}bin/*; do
      copy_bin_and_libs $BIN
    done

    copy_bin_and_libs ${pkgs.dhcpcd}/bin/dhcpcd

    # Copy ld manually since it isn't detected correctly
    cp -pv ${pkgs.glibc.out}/lib/ld*.so.? $out/lib

    # Copy all of the needed libraries
    find $out/bin $out/lib -type f | while read BIN; do
      echo "Copying libs for executable $BIN"
      LDD="$(ldd $BIN)" || continue
      LIBS="$(echo "$LDD" | awk '{print $3}' | sed '/^$/d')"
      for LIB in $LIBS; do
        TGT="$out/lib/$(basename $LIB)"
        if [ ! -f "$TGT" ]; then
          SRC="$(readlink -e $LIB)"
          cp -pdv "$SRC" "$TGT"
        fi
      done
    done

    # Strip binaries further than normal.
    chmod -R u+w $out
    stripDirs "lib bin" "-s"

    # Run patchelf to make the programs refer to the copied libraries.
    find $out/bin $out/lib -type f | while read i; do
      if ! test -L $i; then
        nuke-refs -e $out $i
      fi
    done

    find $out/bin -type f | while read i; do
      if ! test -L $i; then
        echo "patching $i..."
        patchelf --set-interpreter $out/lib/ld*.so.? --set-rpath $out/lib $i || true
      fi
    done

    # Make sure that the patchelf'ed binaries still work.
    echo "testing patched programs..."
    $out/bin/ash -c 'echo hello world' | grep "hello world"
    export LD_LIBRARY_PATH=$out/lib
    $out/bin/mount --help 2>&1 | grep -q "BusyBox"
  '';
  shell = "${extraUtils}/bin/ash";
  enablePlymouth = false;
  dhcpHook = pkgs.writeScript "dhcpHook" ''
  #!${shell}
  '';
  bootStage1 = pkgs.writeScript "stage1" ''
    #!${shell}
    echo
    echo "[1;32m<<< NotOS Stage 1 >>>[0m"
    echo

    export PATH=${extraUtils}/bin/${lib.optionalString enablePlymouth ":${plymouth}/bin/"}
    mkdir -p /proc /sys /dev /etc/udev /tmp /run/ /lib/ /mnt/ /var/log /etc/plymouth /bin
    mount -t devtmpfs devtmpfs /dev/
    mount -t proc proc /proc
    mount -t sysfs sysfs /sys

    ${lib.optionalString enablePlymouth ''
    ln -sv ${plymouth}/lib/plymouth /etc/plymouth/plugins
    ln -sv ${plymouth}/etc/plymouth/plymouthd.conf /etc/plymouth/plymouthd.conf
    ln -sv ${plymouth}/share/plymouth/plymouthd.defaults /etc/plymouth//plymouthd.defaults
    ln -sv ${plymouth}/share/plymouth/themes /etc/plymouth/themes
    ln -sv /dev/fb0 /dev/fb
    ''}
    ln -sv ${shell} /bin/sh
    ln -s ${modules}/lib/modules /lib/modules

    ${lib.optionalString enablePlymouth ''
    # gdb --args plymouthd --debug --mode=boot --no-daemon
    sleep 1
    plymouth --show-splash
    ''}


    for x in ${lib.concatStringsSep " " config.boot.initrd.kernelModules}; do
      modprobe $x
    done

    root=/dev/vda
    realroot=tmpfs
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
        netroot=*)
          set -- $(IFS==; echo $o)
          mkdir -pv /var/run /var/db
          ${lib.optionalString enablePlymouth ''plymouth display-message --text="waiting for eth"''}
          sleep 5
          ${lib.optionalString enablePlymouth ''plymouth display-message --text="dhcp query"''}
          dhcpcd eth0 -c ${dhcpHook}
          ${lib.optionalString enablePlymouth ''plymouth display-message --text="downloading rootfs"''}
          tftp -g -r "$3" "$2"
          root=/root.squashfs
          ;;
        realroot=*)
          set -- $(IFS==; echo $o)
          realroot=$2
          ;;
      esac
    done

    ${lib.optionalString enablePlymouth ''plymouth display-message --text="mounting things"''}

    ${config.not-os.preMount}
    if [ $realroot = tmpfs ]; then
      mount -t tmpfs root /mnt/ -o size=1G || exec ${shell}
    else
      mount $realroot /mnt || exec ${shell}
    fi
    chmod 755 /mnt/
    mkdir -p /mnt/nix/store/


    ${if config.not-os.sd && config.not-os.nix then ''
    mount $root /mnt
    '' else if config.not-os.nix then ''
    # make the store writeable
    mkdir -p /mnt/nix/.ro-store /mnt/nix/.overlay-store /mnt/nix/store
    mount $root /mnt/nix/.ro-store -t squashfs
    if [ $realroot = $1 ]; then
      mount tmpfs -t tmpfs /mnt/nix/.overlay-store -o size=1G
    fi
    mkdir -pv /mnt/nix/.overlay-store/work /mnt/nix/.overlay-store/rw
    modprobe overlay
    mount -t overlay overlay -o lowerdir=/mnt/nix/.ro-store,upperdir=/mnt/nix/.overlay-store/rw,workdir=/mnt/nix/.overlay-store/work /mnt/nix/store
    '' else ''
    # readonly store
    mount $root /mnt/nix/store/ -t squashfs
    ''}

    ${lib.optionalString enablePlymouth ''
    plymouth --newroot=/mnt
    plymouth update-root-fs --new-root-dir=/mnt --read-write
    ''}

    exec env -i $(type -P switch_root) /mnt/ $sysconfig/init
    exec ${shell}
  '';
  initialRamdisk = pkgs.makeInitrd {
    contents = [ { object = bootStage1; symlink = "/init"; } ];
  };
  # Use for zynq_image
  uRamdisk =  pkgs.makeInitrd {
    makeUInitrd = true;
    contents = [ { object = bootStage1; symlink = "/init"; } ];
  };
in
{
  options = {
    not-os.preMount = mkOption {
      type = types.lines;
      default = "";
    };
    boot.initrd.enable = mkOption {
      type = types.bool;
      default = true;
    };
  };
  config = {
    system.build.bootStage1 = bootStage1;
    system.build.initialRamdisk = initialRamdisk;
    system.build.uRamdisk = uRamdisk;
    system.build.extraUtils = extraUtils;
    boot.initrd.availableKernelModules = [ ];
    boot.initrd.kernelModules = [ "tun" "loop" "squashfs" ] ++ (lib.optional config.not-os.nix "overlay");
  };
}
