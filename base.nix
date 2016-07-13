{ pkgs, config, lib, ... }:

with lib;

{
  options = {
    system.build = mkOption {
      internal = true;
      default = {};
      description = "Attribute set of derivations used to setup the system.";
    };
    boot.isContainer = mkOption {
      type = types.bool;
      default = false;
    };
    hardware.firmware = mkOption {
      type = types.listOf types.package;
      default = [];
      apply = list: pkgs.buildEnv {
        name = "firmware";
        paths = list;
        pathsToLink = [ "/lib/firmware" ];
        ignoreCollisions = true;
      };
    };
  };
  config = {
    nixpkgs.config = {
      packageOverrides = self: {
        utillinux = self.utillinux.override { systemd = null; };
        toxvpn = self.toxvpn.overrideDerivation (x: { cmakeFlags = [ "-DSTATIC=1" ]; nativeBuildInputs = lib.filter (y: y.name != "systemd-230") x.nativeBuildInputs; });
      };
    };
    environment.etc = {
      profile.text = "export PATH=/run/current-system/sw/bin";
      "resolv.conf".text = "nameserver 10.0.2.3";
      passwd.text = ''
        root:x:0:0:System administrator:/root:/run/current-system/sw/bin/bash
        sshd:x:498:65534:SSH privilege separation user:/var/empty:/run/current-system/sw/bin/nologin
        toxvpn:x:1010:65534::/var/lib/toxvpn:/run/current-system/sw/bin/nologin
      '';
      "ssh/ssh_host_rsa_key.pub".source = ./ssh/ssh_host_rsa_key.pub;
      "ssh/ssh_host_rsa_key" = { mode = "0600"; source = ./ssh/ssh_host_rsa_key; };
      "ssh/ssh_host_ed25519_key.pub".source = ./ssh/ssh_host_ed25519_key.pub;
      "ssh/ssh_host_ed25519_key" = { mode = "0600"; source = ./ssh/ssh_host_ed25519_key; };
    };
    boot.kernelParams = [ "systemConfig=${config.system.build.toplevel}" ];
    boot.kernelPackages = if pkgs.system == "armv6l-linux" then pkgs.linuxPackages_rpi else pkgs.linuxPackages;
    system.build.runvm = pkgs.writeScript "runner" ''
      #!${pkgs.stdenv.shell}
      exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name not-os -m 512 \
        -drive index=0,id=drive1,file=${config.system.build.squashfs},readonly,media=cdrom,format=raw,if=virtio \
        -kernel ${config.system.build.kernel}/bzImage -initrd ${config.system.build.initialRamdisk}/initrd -nographic \
        -append "console=ttyS0 ${toString config.boot.kernelParams} quiet panic=-1" -no-reboot \
        -net nic,vlan=0,model=virtio \
        -net user,vlan=0,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22 \
        -net dump,vlan=0 \
        -device virtio-rng-pci
    '';

    system.build.dist = pkgs.runCommand "not-os-dist" {} ''
      mkdir $out
      cp ${config.system.build.squashfs} $out/root.squashfs
      cp ${config.system.build.kernel}/bzImage $out/kernel
      cp ${config.system.build.initialRamdisk}/initrd $out/initrd
      echo "${toString config.boot.kernelParams}" > $out/command-line
    '';

    # nix-build -A system.build.toplevel && du -h $(nix-store -qR result) --max=0 -BM|sort -n
    system.build.toplevel = pkgs.runCommand "not-os" {
      activationScript = config.system.activationScripts.script;
    } ''
      mkdir $out
      cp ${config.system.build.bootStage2} $out/init
      substituteInPlace $out/init --subst-var-by systemConfig $out
      ln -s ${config.system.path} $out/sw
      echo "$activationScript" > $out/activate
      substituteInPlace $out/activate --subst-var out
      chmod u+x $out/activate
      unset activationScript
    '';
    # nix-build -A squashfs && ls -lLh result
    system.build.squashfs = pkgs.callPackage <nixpkgs/nixos/lib/make-squashfs.nix> {
      storeContents = [ config.system.build.toplevel ];
    };
  };
}
