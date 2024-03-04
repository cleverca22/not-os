{ lib, config, pkgs, ... }:

with lib;
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
      MEDIA_SUPPORT n
      FB n
      DRM n
      SOUND n
      SQUASHFS n
      BACKLIGHT_CLASS_DEVICE n
      FPGA y
      FPGA_BRIDGE y
      FPGA_REGION y
      OF_FPGA_REGION y
      FPGA_MGR_ZYNQ_FPGA y
      OF_OVERLAY y
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
  not-os.simpleStaticIp = true;
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
    systemPackages = with pkgs; [ inetutils wget nano ];
    etc = {
      "service/getty/run".source = pkgs.writeShellScript "getty" ''
        hostname ${config.networking.hostName}
        exec setsid agetty ttyPS0 115200
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
  boot.postBootCommands = lib.mkIf config.not-os.sd ''
    # On the first boot do some maintenance tasks
    if [ -f /nix-path-registration ]; then
      set -euo pipefail
      set -x
      # Figure out device names for the boot device and root filesystem.
      rootPart=$(${pkgs.utillinux}/bin/findmnt -n -o SOURCE /)
      bootDevice=$(lsblk -npo PKNAME $rootPart)
      partNum=$(lsblk -npo MAJ:MIN $rootPart | ${pkgs.gawk}/bin/awk -F: '{print $2}')

      # Resize the root partition and the filesystem to fit the disk
      echo ",+," | sfdisk -N$partNum --no-reread $bootDevice
      ${pkgs.parted}/bin/partprobe
      ${pkgs.e2fsprogs}/bin/resize2fs $rootPart

      # Register the contents of the initial Nix store
      nix-store --load-db < /nix-path-registration

      # nixos-rebuild also requires a "system" profile and an /etc/NIXOS tag.
      touch /etc/NIXOS
      nix-env -p /nix/var/nix/profiles/system --set /run/current-system

      # Prevents this from running on later boots.
      rm -f /nix-path-registration
    fi
  '';
}
