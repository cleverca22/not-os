{ pkgs, config, ... }:

let
  ipxe_script = pkgs.writeText "script.ipxe" ''
    #!ipxe
    :restart
    menu iPXE boot menu
    item normal Boot normally
    item loop Start iPXE shell
    item off Shutdown
    item reset Reboot
    choose --default normal --timeout 5000 res || goto restart
    goto ''${res}

    :off
    poweroff
    goto off
    :reset
    reboot
    goto reset

    :normal
    imgfree
    imgfetch tftp://10.0.2.2/kernel root=/root.squashfs console=tty0 console=ttyS0 panic=-1 ${toString config.boot.kernelParams} || goto normal
    imgfetch tftp://10.0.2.2/initrd || goto normal
    imgfetch tftp://10.0.2.2/root.squashfs root.squashfs || goto normal
    imgverify kernel tftp://10.0.2.2/kernel.sig
    imgverify initrd tftp://10.0.2.2/initrd.sig
    imgverify root.squashfs tftp://10.0.2.2/root.squashfs.sig
    imgselect kernel
    boot

    :loop
    login || goto cancelled

    iseq ''${password} hunter2 && goto is_correct ||
    echo password wrong
    sleep 5
    goto loop

    :cancelled
    echo you gave up, goodbye
    sleep 5
    poweroff
    goto cancelled

    :is_correct
    shell
  '';
  ftpdir = pkgs.runCommand "ftpdir" { buildInputs = [ pkgs.openssl ]; } ''
    mkdir $out
    ln -sv ${config.system.build.dist}/kernel $out/
    ln -sv ${config.system.build.dist}/initrd $out/
    ln -sv ${config.system.build.dist}/root.squashfs $out/
    ln -sv ${ipxe_script} $out/script.ipxe
    function signit {
      openssl cms -sign -binary -noattr -in $1 -signer ${./ca/codesign.crt} -inkey ${./ca/codesign.key} -certfile ${./ca/root.pem} -outform DER -out ''${1}.sig
    }
    signit $out/kernel
    signit $out/initrd
    signit $out/script.ipxe
    signit $out/root.squashfs
  '';
  ipxe = pkgs.lib.overrideDerivation pkgs.ipxe (x: {
    script = pkgs.writeText "embed.ipxe" ''
      #!ipxe
      imgtrust --permanent
      dhcp
      imgfetch tftp://10.0.2.2/script.ipxe
      imgverify script.ipxe tftp://10.0.2.2/script.ipxe.sig
      chain script.ipxe
      echo temporary debug shell
      shell
    '';
    ca_cert = ./ca/root.pem;
    nativeBuildInputs = x.nativeBuildInputs ++ [ pkgs.openssl ];
    makeFlags = x.makeFlags ++ [
      ''EMBED=''${script}''
      ''TRUST=''${ca_cert}''
      "CERT=${./ca/codesign.crt},${./ca/root.pem}"
      #"bin-i386-efi/ipxe.efi" "bin-i386-efi/ipxe.efidrv"
    ];

    enabledOptions = x.enabledOptions ++ [ "CONSOLE_SERIAL" "POWEROFF_CMD" "IMAGE_TRUST_CMD" ];
  });
  testipxe = pkgs.writeScript "runner" ''
    #!${pkgs.stdenv.shell}
    exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name not-os -m 512 \
      -kernel ${ipxe}/ipxe.lkrn  \
      -net nic,vlan=0,model=virtio \
      -net user,vlan=0,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22,tftp=${ftpdir} \
      -net dump,vlan=0 \
      -device virtio-rng-pci -serial stdio
  '';
in
{
  options = {
  };
  config = {
    system.build = {
      inherit ipxe_script ftpdir ipxe testipxe;
    };
  };
}
