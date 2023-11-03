{
  inputs = {
    firmware = {
      url = "github:raspberrypi/firmware";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, firmware }: {
    packages.armv7l-linux = let
      platforms = (import nixpkgs { config = {}; }).platforms;
      eval = (import ./default.nix {
        extraModules = [
          ./rpi_image.nix
          { system.build.rpi_firmware = firmware; }
        ];
        platform = system: platforms.raspberrypi2;
        system = "x86_64-linux";
        crossSystem.system = "armv7l-linux";
        inherit nixpkgs;
      });
      zynq_eval = (import ./. {
        extraModules = [
          ./zynq_image.nix
        ];
        platform = system: platforms.raspberrypi2;
        system = "x86_64-linux";
        crossSystem.system = "armv7l-linux";
        inherit nixpkgs;
      });
    in {
      rpi_image = eval.config.system.build.rpi_image;
      rpi_image_tar = eval.config.system.build.rpi_image_tar;
      toplevel = eval.config.system.build.toplevel;
      zynq_image = zynq_eval.config.system.build.zynq_image;
    };
    hydraJobs = {
      armv7l-linux = {
        rpi_image_tar = self.packages.armv7l-linux.rpi_image_tar;
        zynq_image = self.packages.armv7l-linux.zynq_image;
      };
    };
  };
}
