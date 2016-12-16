{ stdenv, fetchFromGitHub, perl, buildLinux, ... } @ args:

let
  modDirVersion = "4.4.36";
  tag = "1.20161020-1";
in
stdenv.lib.overrideDerivation (import <nixpkgs/pkgs/os-specific/linux/kernel/generic.nix> (args // rec {
  version = "${modDirVersion}-${tag}";
  inherit modDirVersion;

  src = fetchFromGitHub {
    owner = "raspberrypi";
    repo = "linux";
    rev = "c6d86f7aa554854b04614ebb4d394766081fb41f";
    sha256 = "13rjmks4whh7kn0wrswanwq3b0ia9bxsq8a6xiqiivh6k3vxqhys";
  };

  features.iwlwifi = true;
  features.needsCifsUtils = true;
  features.canDisableNetfilterConntrackHelpers = true;
  features.netfilterRPFilter = true;

  extraMeta.hydraPlatforms = [];
})) (oldAttrs: {
  postConfigure = ''
    # The v7 defconfig has this set to '-v7' which screws up our modDirVersion.
    sed -i $buildRoot/.config -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=""/'
  '';

  postFixup = ''
    # Make copies of the DTBs so that U-Boot finds them, as it is looking for the upstream names.
    # This is ugly as heck.
    copyDTB() {
      if [ -f "$out/dtbs/$1" ]; then
        cp -v "$out/dtbs/$1" "$out/dtbs/$2"
      fi
    }

    # I am not sure if all of these are correct...
    copyDTB bcm2708-rpi-b.dtb bcm2835-rpi-a.dtb
    copyDTB bcm2708-rpi-b.dtb bcm2835-rpi-b.dtb
    copyDTB bcm2708-rpi-b.dtb bcm2835-rpi-b-rev2.dtb
    copyDTB bcm2708-rpi-b-plus.dtb bcm2835-rpi-a-plus.dtb
    copyDTB bcm2708-rpi-b-plus.dtb bcm2835-rpi-b-plus.dtb
    copyDTB bcm2708-rpi-b-plus.dtb bcm2835-rpi-zero.dtb
    copyDTB bcm2708-rpi-cm.dtb bcm2835-rpi-cm.dtb
    copyDTB bcm2709-rpi-2-b.dtb bcm2836-rpi-2-b.dtb
    copyDTB bcm2710-rpi-3-b.dtb bcm2837-rpi-3-b.dtb
  '';
})
