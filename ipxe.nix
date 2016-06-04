{ pkgs, config, ... }:

let
  ipxe_script = pkgs.writeText "script.ipxe" ''
    #!ipxe
    set net0/next-server 10.0.2.2
    imgfetch tftp://10.0.2.2/kernel console=ttyS0 panic=-1 ${config.system.build.kernel-params}
    imgfetch tftp://10.0.2.2/initrd
    imgverify kernel tftp://10.0.2.2/kernel.sig
    imgverify initrd tftp://10.0.2.2/initrd.sig
    imgselect kernel

    prompt --key 0x02 --timeout 5000 Press Ctrl-B for the iPXE command line... && goto loop ||
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
    ln -sv ${ipxe_script} $out/script.ipxe
    function signit {
      openssl cms -sign -binary -noattr -in $1 -signer ${./ca/codesign.crt} -inkey ${./ca/codesign.key} -certfile ${./ca/root.pem} -outform DER -out ''${1}.sig
    }
    signit $out/kernel
    signit $out/initrd
    signit $out/script.ipxe
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
    ];
    preConfigure = ''
      cd src
      cat << EOF > config/local/general.h
#define CONSOLE_SERIAL
#define POWEROFF_CMD
#define IMAGE_TRUST_CMD
EOF
    '';
  });
  testipxe = pkgs.writeScript "runner" ''
    #!${pkgs.stdenv.shell}
    exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name not-os -m 512 \
      -kernel ${ipxe}/ipxe.lkrn -nographic \
      -drive index=0,id=drive1,file=${config.system.build.squashfs},readonly,media=cdrom,format=raw,if=virtio \
      -net nic,vlan=0,model=virtio \
      -net user,vlan=0,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22,tftp=${ftpdir} \
      -net dump,vlan=0 \
      -device virtio-rng-pci
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
