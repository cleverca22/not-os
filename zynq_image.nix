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
  networking.hostName = "zynq";
  system.build.zynq_image = pkgs.runCommand "zynq_image" {
    preferLocalBuild = true;
  } ''
    mkdir $out
    cd $out
    cp -s ${config.system.build.kernel}/*zImage .
    cp -s ${config.system.build.initialRamdisk}/initrd initrd
    cp -s ${config.system.build.kernel}/dtbs/zynq-zc702.dtb .
    ln -sv ${config.system.build.toplevel} toplevel
  '';
  environment = {
    systemPackages = with pkgs; [ strace inetutils ];
    etc = {
      "service/getty/run".source = pkgs.writeShellScript "getty" ''
        hostname ${config.networking.hostName}
        agetty ttyPS0 115200
      '';
      "pam.d/other".text = ''
        auth     sufficient pam_permit.so
        account  required pam_permit.so
        password required pam_permit.so
        session  optional pam_env.so
      '';
      "security/pam_env.conf".text = "";
    };
  };
}
