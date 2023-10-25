{ sshKeyFile ? null, memory ? 512, rootsize ? "10g" }:
# usage: nix-build linux-build-slave.nix -I nixpkgs=https://github.com/nixos/nixpkgs/archive/c29d2fde74d.tar.gz --arg sshKeyFile ~/.ssh/id_rsa.pub
let
  pkgs = import <nixpkgs> {};
  eval = import ./. {
    inherit configuration;
    system = "x86_64-linux";
  };
  configuration = { pkgs, ... }: {
    imports = [ ./qemu.nix ];
    not-os = {
      nix = true;
      simpleStaticIp = true;
      preMount = ''
        ${pkgs.e2fsprogs}/bin/mkfs.ext4 $realroot || true
      '';
    };
    boot.kernelParams = [ "realroot=/dev/vdb" ];
    boot.initrd.kernelModules = [ "ext4" "crc32c_generic" ];
    environment.systemPackages = with pkgs; [ ];
    environment.etc = {
      "ssh/authorized_keys.d/root" = {
        text = "${if (sshKeyFile != null) then builtins.readFile sshKeyFile else ""}";
        mode = "0444";
      };
    };
  };
  runvm = pkgs.writeScript "runner" ''
    #!${pkgs.stdenv.shell}
    set -e

    export PATH=${pkgs.coreutils}/bin/:$PATH

    rm -f rootdisk.img
    truncate -s ${rootsize} rootdisk.img

    exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name buildSlave -m ${toString memory} \
      -drive index=0,id=drive0,file=${eval.config.system.build.squashfs},readonly=on,media=cdrom,format=raw,if=virtio \
      -drive index=1,id=drive1,file=rootdisk.img,format=raw,if=virtio \
      -kernel ${eval.config.system.build.kernel}/bzImage -initrd ${eval.config.system.build.initialRamdisk}/initrd -nographic \
      -append "console=ttyS0 ${toString eval.config.boot.kernelParams} quiet panic=-1" -no-reboot \
      -net nic,model=virtio \
      -net user,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22 \
      -device virtio-rng-pci
  '';
in {
  inherit runvm;
}
