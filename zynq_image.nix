{ config, pkgs, ... }:

let
  crosspkgs = import pkgs.path {
    system = "x86_64-linux";
    crossSystem = {
      system = "armv7l-linux";
      linux-kernel = {
        name = "zynq";
        baseConfig = "multi_v7_defconfig";
        target = "uImage";
        installTarget = "uImage";
        autoModules = false;
        DTB = true;
        makeFlags = [ "LOADADDR=0x8000" ];
      };
    };
  };
  customKernel = (crosspkgs.linux.override {
    extraConfig = ''
      OVERLAY_FS y
    '';
  }).overrideAttrs (oa: {
    postInstall = ''
      cp arch/arm/boot/uImage $out
      ${oa.postInstall}
    '';
  });
  customKernelPackages = crosspkgs.linuxPackagesFor customKernel;
in {
  imports = [ ./arm32-cross-fixes.nix ];
  boot.kernelPackages = customKernelPackages;
  nixpkgs.system = "armv7l-linux";
  networking.hostName = "zynq";
  not-os.sd = true;
  system.build.zynq_image = pkgs.runCommand "zynq_image" {
    preferLocalBuild = true;
  } ''
    mkdir $out
    cd $out
    cp -s ${config.system.build.kernel}/uImage .
    cp -s ${config.system.build.uRamdisk}/initrd uRamdisk.image.gz
    cp -s ${config.system.build.kernel}/dtbs/zynq-zc706.dtb devicetree.dtb
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
