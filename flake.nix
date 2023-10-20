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
    in {
      rpi_image = (import ./default.nix {
        extraModules = [
          ./rpi_image.nix
          { system.build.rpi_firmware = firmware; }
        ];
        platform = system: platforms.raspberrypi2;
        system = "armv7l-linux";
        inherit nixpkgs;
      }).config.system.build.rpi_image;
    };
  };
}
