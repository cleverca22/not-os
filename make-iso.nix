{ config, lib, pkgs, ... }:

with lib;

let
  max = x: y: if x > y then x else y;

  # The configuration file for syslinux.

  # Notes on syslinux configuration and UNetbootin compatiblity:
  #   * Do not use '/syslinux/syslinux.cfg' as the path for this
  #     configuration. UNetbootin will not parse the file and use it as-is.
  #     This results in a broken configuration if the partition label does
  #     not match the specified config.isoImage.volumeID. For this reason
  #     we're using '/isolinux/isolinux.cfg'.
  #   * Use APPEND instead of adding command-line arguments directly after
  #     the LINUX entries.
  #   * COM32 entries (chainload, reboot, poweroff) are not recognized. They
  #     result in incorrect boot entries.

  baseIsolinuxCfg = ''
    SERIAL 0 38400
    TIMEOUT 10
    UI vesamenu.c32
    MENU TITLE NotOS
    MENU BACKGROUND /isolinux/background.png
    DEFAULT boot

    LABEL boot
    MENU LABEL NotOS
    LINUX /boot/kernel
    APPEND ${toString config.boot.kernelParams} panic=-1
    INITRD /boot/initrd
  '';

  isolinuxCfg = baseIsolinuxCfg;
  targetArch = if pkgs.stdenv.isi686 then
    "ia32"
  else if pkgs.stdenv.isx86_64 then
    "x64"
  else
    throw "Unsupported architecture";

in

{
  options = {

    isoImage.isoName = mkOption {
      default = "${config.isoImage.isoBaseName}.iso";
      description = ''
        Name of the generated ISO image file.
      '';
    };

    isoImage.isoBaseName = mkOption {
      default = "not-os";
      description = ''
        Prefix of the name of the generated ISO image file.
      '';
    };

    isoImage.compressImage = mkOption {
      default = false;
      description = ''
        Whether the ISO image should be compressed using
        <command>bzip2</command>.
      '';
    };

    isoImage.volumeID = mkOption {
      default = "NOTOS_BOOT_CD";
      description = ''
        Specifies the label or volume ID of the generated ISO image.
        Note that the label is used by stage 1 of the boot process to
        mount the CD, so it should be reasonably distinctive.
      '';
    };

    isoImage.contents = mkOption {
      example = literalExample ''
        [ { source = pkgs.memtest86 + "/memtest.bin";
            target = "boot/memtest.bin";
          }
        ]
      '';
      description = ''
        This option lists files to be copied to fixed locations in the
        generated ISO image.
      '';
    };

    isoImage.splashImage = mkOption {
      default = pkgs.fetchurl {
          url = https://raw.githubusercontent.com/NixOS/not-os-artwork/5729ab16c6a5793c10a2913b5a1b3f59b91c36ee/ideas/grub-splash/grub-not-os-1.png;
          sha256 = "43fd8ad5decf6c23c87e9026170a13588c2eba249d9013cb9f888da5e2002217";
        };
      description = ''
        The splash image to use in the bootloader.
      '';
    };
  };

  config = {
    # !!! Hack - attributes expected by other modules.
    environment.systemPackages = [ ];

    # In stage 1 of the boot, mount the CD as the root FS by label so
    # that we don't need to know its device.  We pass the label of the
    # root filesystem on the kernel command line, rather than in
    # `fileSystems' below.  This allows CD-to-USB converters such as
    # UNetbootin to rewrite the kernel command line to pass the label or
    # UUID of the USB stick.  It would be nicer to write
    # `root=/dev/disk/by-label/...' here, but UNetbootin doesn't
    # recognise that.
    boot.kernelParams =
      [ "root=/cdrom/nix-store.squashfs"
        # "root=LABEL=${config.isoImage.volumeID}"
        # "boot.shell_on_fail"
      ];

    boot.initrd.availableKernelModules = [];

    boot.initrd.kernelModules = [
      "ata_piix"  # PIIX for VirtualBox
      "sr_mod"    # CD Device Driver
      "iso9660"   # CD File System
      "e1000"     # Network Driver
      "af_packet" # CONFIG_PACKET
    ];

    not-os.preMount = ''
      mkdir -p /cdrom
      mount -t iso9660 /dev/sr0 /cdrom
    '';

    # Individual files to be included on the CD, outside of the Nix
    # store on the CD.
    isoImage.contents =
      [ { source = pkgs.substituteAll  {
            name = "isolinux.cfg";
            src = pkgs.writeText "isolinux.cfg-in" isolinuxCfg;
            bootRoot = "/boot";
          };
          target = "/isolinux/isolinux.cfg";
        }
        { source = "${config.system.build.kernel}/bzImage";
          target = "/boot/kernel";
        }
        { source = "${config.system.build.initialRamdisk}/initrd";
          target = "/boot/initrd";
        }
        { source = config.system.build.squashfs;
          target = "/nix-store.squashfs";
        }
        { source = "${pkgs.syslinux}/share/syslinux";
          target = "/isolinux";
        }
        { source = config.isoImage.splashImage;
          target = "/isolinux/background.png";
        }
        { source = pkgs.writeText "version" "NotOS";
          target = "/version.txt";
        }
      ];

    # Create the ISO image.
    system.build.isoImage = pkgs.callPackage (pkgs.path + "/nixos/lib/make-iso9660-image.nix") {
      inherit (config.isoImage) isoName compressImage volumeID contents;
      bootable = true;
      bootImage = "/isolinux/isolinux.bin";
    };
  };
}
