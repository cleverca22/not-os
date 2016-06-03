with import <nixpkgs> {};

rec {
  stage1 = writeScript "stage1" ''
    #!${stdenv.shell}
    export PATH=${busybox}/bin/
    mkdir -p /proc /sys /dev /etc/udev /tmp /run/ /lib/ /mnt/
    mount -t devtmpfs devtmpfs /dev/
    mount -t proc proc /proc

    ln -s ${modules}/lib/modules /lib/modules

    modprobe virtio
    modprobe virtio_pci
    modprobe virtio_net

    modprobe virtio_blk
    modprobe squashfs
    
    for o in $(cat /proc/cmdline); do
      case $o in
        init=*)
          set -- $(IFS==; echo $o)
          stage2Init=$2
          ;;
        systemConfig=*)
          set -- $(IFS==; echo $o)
          sysconfig=$2
          ;;
      esac
    done
    mount -t tmpfs root /mnt/
    chmod 755 /mnt/
    mkdir -p /mnt/nix/store/ /mnt/run/
    ln -s $sysconfig /mnt/run/current-system
    
    mount /dev/vda /mnt/nix/store/ -t squashfs

    exec env -i $(type -P switch_root) /mnt/ $sysconfig/init
    exec ${stdenv.shell}
  '';
  modules = makeModulesClosure {
    rootModules = [ "squashfs" "virtio" "virtio_pci" "virtio_blk" "virtio_net" ];
    kernel = linux;
  };
  initrd = makeInitrd {
    contents = [ { object = stage1; symlink = "/init"; } ];
  };
  modprobe = stdenv.mkDerivation {
    name = "modprobe";
    buildCommand = ''
      mkdir -p $out/bin
      for i in ${pkgs.kmod}/sbin/*; do
        name=$(basename $i)
        echo "$text" > $out/bin/$name
        echo 'exec '$i' "$@"' >> $out/bin/$name
        chmod +x $out/bin/$name
      done
      ln -s bin $out/sbin
    '';
    text = ''
      #! ${pkgs.stdenv.shell}
      export MODULE_DIR=/run/current-system/kernel-modules/lib/modules
      if [ ! -d "$MODULE_DIR/$(${pkgs.coreutils}/bin/uname -r)" ]; then
        MODULE_DIR=/run/booted-system/kernel-modules/lib/modules/
      fi
    '';
  };
  modulesTree = aggregateModules [ linux ];
  systemPath = buildEnv {
    name = "system-path";
    # utillinux can replace busybox, but depends on systemd currently
    # coreutils iproute modprobe iputils
    paths = [ busybox procps curl bash ];
  };
  sshd_config = writeText "sshd_config" ''
    HostKey /etc/ssh/ssh_host_rsa_key
    HostKey /etc/ssh/ssh_host_ed25519_key
    Port 22
    PidFile /run/sshd.pid
    Protocol 2
    PermitRootLogin yes
    PasswordAuthentication yes
    AuthorizedKeysFile /etc/ssh/authorized_keys.d/%u
  '';
  passwd = writeText "passwd" ''
    root:x:0:0:System administrator:/root:/run/current-system/sw/bin/bash
    sshd:x:498:65534:SSH privilege separation user:/var/empty:/run/current-system/sw/bin/nologin
  '';
  resolvconf = writeText "resolv.conf" ''
    nameserver 10.0.2.3
  '';
  ssh_pubkey = writeText "pubkey" ''
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC34wZQFEOGkA5b0Z6maE3aKy/ix1MiK1D0Qmg4E9skAA57yKtWYzjA23r5OCF4Nhlj1CuYd6P1sEI/fMnxf+KkqqgW3ZoZ0+pQu4Bd8Ymi3OkkQX9kiq2coD3AFI6JytC6uBi6FaZQT5fG59DbXhxO5YpZlym8ps1obyCBX0hyKntD18RgHNaNM+jkQOhQ5OoxKsBEobxQOEdjIowl2QeEHb99n45sFr53NFqk3UCz0Y7ZMf1hSFQPuuEC/wExzBBJ1Wl7E1LlNA4p9O3qJUSadGZS4e5nSLqMnbQWv2icQS/7J8IwY0M8r1MsL8mdnlXHUofPlG1r4mtovQ2myzOx clever@nixos
  '';
  profile = writeText "profile" ''
    export PATH=/run/current-system/sw/bin
  '';
  etcs = [
    { source = passwd; target = "passwd"; mode = "symlink"; uid = 0; gid = 0; }
    { source = resolvconf; target = "resolv.conf"; mode = "symlink"; uid=0; gid=0; }
    { source = ssh_pubkey; target="ssh/authorized_keys.d/root"; mode="0444"; uid=0; gid=0; }
    { source=./ssh/ssh_host_rsa_key.pub; target="ssh/ssh_host_rsa_key.pub"; mode="symlink"; uid=0; gid=0; }
    { source=./ssh/ssh_host_rsa_key; target="ssh/ssh_host_rsa_key"; mode="0600"; uid=0; gid=0; }
    { source=./ssh/ssh_host_ed25519_key.pub; target="ssh/ssh_host_ed25519_key.pub"; mode="symlink"; uid=0; gid=0; }
    { source=./ssh/ssh_host_ed25519_key; target="ssh/ssh_host_ed25519_key"; mode="0600"; uid=0; gid=0; }
    { source=profile; target="profile"; mode="symlink"; uid=0; gid=0; }
  ];
  etc = stdenv.mkDerivation {
    name = "etc";
    builder = <nixpkgs/nixos/modules/system/etc/make-etc.sh>;
    preferLocalBuild = true;
    allowSubstitutes = false;

    sources = map (x: x.source) etcs;
    targets = map (x: x.target) etcs;
    modes = map (x: x.mode) etcs;
    uids = map (x: x.uid) etcs;
    gids = map (x: x.gid) etcs;
  };
  init = writeScript "init" ''
    #!${stdenv.shell}
    export PATH=${systemPath}/bin/
    mkdir -p /proc /sys /dev /tmp/ssh /var/log /etc /root/
    mount -t proc proc /proc
    mount -t sysfs sys /sys
    mount -t devtmpfs devtmpfs /dev
    mkdir /dev/pts
    mount -t devpts devpts /dev/pts
    ip addr add 10.0.2.15 dev eth0
    ip link set eth0 up
    ip route add 10.0.2.0/24 dev eth0
    ip route add default via 10.0.2.2 dev eth0
    #ln -s /run/current-system/etc/ /etc
    ${perl}/bin/perl -I${pkgs.perlPackages.FileSlurp}/lib/perl5/site_perl ${<nixpkgs/nixos/modules/system/etc/setup-etc.pl>} ${etc}/etc

    ${openssh}/bin/sshd -f ${sshd_config} -d

    ls -ltrhR /etc/

    #curl www.google.com
    #sleep 300
    echo o > /proc/sysrq-trigger
    stty erase ^H
    setsid ${stdenv.shell} < /dev/ttyS0 > /dev/ttyS0 2>&1
  '';
  # nix-build -A toplevel && du -h $(nix-store -qR result) --max=0 -BM|sort -n
  toplevel = runCommand "not-os" {} ''
    mkdir $out
    ln -s ${init} $out/init
    ln -s ${modulesTree} $out/kernel-modules
    ln -s ${systemPath} $out/sw
  '';
  # nix-build -A squashfs && ls -lLh result
  squashfs = callPackage <nixpkgs/nixos/lib/make-squashfs.nix> { storeContents = [ toplevel ]; };
  cmdline = "init=${init} systemConfig=${toplevel}";
  runner = writeScript "runner" ''
    #!${stdenv.shell}
    exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name not-os -m 512 -drive index=0,id=drive1,file=${squashfs},readonly,media=cdrom,format=raw,if=virtio \
      -kernel ${linux}/bzImage -initrd ${initrd}/initrd -nographic -append "console=ttyS0 ${cmdline} quiet panic=-1" -no-reboot \
      -net nic,vlan=0,model=virtio -net user,vlan=0,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22 \
      -net dump,vlan=0
  '';
  dist = runCommand "not-os-dist" {} ''
    mkdir $out
    cp ${squashfs} $out/root.squashfs
    cp ${linux}/bzImage $out/kernel
    echo "${cmdline}" > $out/command-line
  '';
}
