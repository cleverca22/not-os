{ pkgs, config, lib, ... }:

with lib;

let
  sshd_config = pkgs.writeText "sshd_config" ''
    HostKey /etc/ssh/ssh_host_rsa_key
    HostKey /etc/ssh/ssh_host_ed25519_key
    Port 22
    PidFile /run/sshd.pid
    Protocol 2
    PermitRootLogin yes
    PasswordAuthentication yes
    AuthorizedKeysFile /etc/ssh/authorized_keys.d/%u
  '';
  cmdline = "init=${config.system.build.bootStage2} systemConfig=${config.system.build.toplevel}";
in
{
  options = {
    system.build = mkOption {
      internal = true;
      default = {};
      description = "Attribute set of derivations used to setup the system.";
    };
  };
  config = {
    environment.etc = {
      profile.text = "export PATH=/run/current-system/sw/bin";
      "resolv.conf".text = "nameserver 10.0.2.3";
      passwd.text = ''
        root:x:0:0:System administrator:/root:/run/current-system/sw/bin/bash
        sshd:x:498:65534:SSH privilege separation user:/var/empty:/run/current-system/sw/bin/nologin
      '';
      "ssh/authorized_keys.d/root" = {
        text = ''
          ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC34wZQFEOGkA5b0Z6maE3aKy/ix1MiK1D0Qmg4E9skAA57yKtWYzjA23r5OCF4Nhlj1CuYd6P1sEI/fMnxf+KkqqgW3ZoZ0+pQu4Bd8Ymi3OkkQX9kiq2coD3AFI6JytC6uBi6FaZQT5fG59DbXhxO5YpZlym8ps1obyCBX0hyKntD18RgHNaNM+jkQOhQ5OoxKsBEobxQOEdjIowl2QeEHb99n45sFr53NFqk3UCz0Y7ZMf1hSFQPuuEC/wExzBBJ1Wl7E1LlNA4p9O3qJUSadGZS4e5nSLqMnbQWv2icQS/7J8IwY0M8r1MsL8mdnlXHUofPlG1r4mtovQ2myzOx clever@nixos
        '';
        mode = "0444";
      };
      "ssh/ssh_host_rsa_key.pub".source = ./ssh/ssh_host_rsa_key.pub;
      "ssh/ssh_host_rsa_key" = { mode = "0600"; source = ./ssh/ssh_host_rsa_key; };
      "ssh/ssh_host_ed25519_key.pub".source = ./ssh/ssh_host_ed25519_key.pub;
      "ssh/ssh_host_ed25519_key" = { mode = "0600"; source = ./ssh/ssh_host_ed25519_key; };
    };
    system.build.runvm = pkgs.writeScript "runner" ''
      #!${pkgs.stdenv.shell}
      exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name not-os -m 512 \
        -drive index=0,id=drive1,file=${config.system.build.squashfs},readonly,media=cdrom,format=raw,if=virtio \
        -kernel ${pkgs.linux}/bzImage -initrd ${config.system.build.initialRamdisk}/initrd -nographic \
        -append "console=ttyS0 ${cmdline} quiet panic=-1" -no-reboot \
        -net nic,vlan=0,model=virtio \
        -net user,vlan=0,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22 \
        -net dump,vlan=0
    '';

    system.build.bootStage2 =  pkgs.writeScript "init" ''
      #!${pkgs.stdenv.shell}
      export PATH=${config.system.path}/bin/
      mkdir -p /proc /sys /dev /tmp/ssh /var/log /etc /root/
      mount -t proc proc /proc
      mount -t sysfs sys /sys
      mount -t devtmpfs devtmpfs /dev
      mkdir /dev/pts
      mount -t devpts devpts /dev/pts
      ip addr add 10.0.2.15 dev eth0
      ip link set eth0 up
      ip route add 10.0.2.0/24 dev eth0
      ip  route add default via 10.0.2.2 dev eth0
      #ln -s /run/current-system/etc/ /etc
      ${pkgs.perl}/bin/perl -I${pkgs.perlPackages.FileSlurp}/lib/perl5/site_perl ${<nixpkgs/nixos/modules/system/etc/setup-etc.pl>} ${config.system.build.etc}/etc

      ${pkgs.openssh}/bin/sshd -f ${sshd_config} -d

      #curl www.google.com
      #sleep 300
      echo o > /proc/sysrq-trigger
      stty erase ^H
      setsid ${pkgs.stdenv.shell} < /dev/ttyS0 > /dev/ttyS0 2>&1
    '';
    system.build.dist = pkgs.runCommand "not-os-dist" {} ''
      mkdir $out
      cp ${config.system.build.squashfs} $out/root.squashfs
      cp ${pkgs.linux}/bzImage $out/kernel
      cp ${config.system.build.initialRamdisk} $out/initrd
      echo "${cmdline}" > $out/command-line
    '';

    # nix-build -A system.build.toplevel && du -h $(nix-store -qR result) --max=0 -BM|sort -n
    system.build.toplevel = pkgs.runCommand "not-os" {} ''
      mkdir $out
      ln -s ${config.system.build.bootStage2} $out/init
      ln -s ${config.system.path} $out/sw
    '';
    # nix-build -A squashfs && ls -lLh result
    system.build.squashfs = pkgs.callPackage <nixpkgs/nixos/lib/make-squashfs.nix> {
      storeContents = [ config.system.build.toplevel ];
    };
  };
}
