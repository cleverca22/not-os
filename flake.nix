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
        system = "armv7l-linux";
        inherit nixpkgs;
      });
    in {
      rpi_image = eval.config.system.build.rpi_image;
      toplevel = eval.config.system.build.toplevel;
      inherit eval;
    };
  };
}
