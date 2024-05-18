{ config, lib, pkgs, ... }:

# based heavily on https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/system-path.nix
#  crosser = if pkgs.stdenv ? cross then (x: if x ? crossDrv then x.crossDrv else x) else (x: x);

with lib;

let
  requiredPackages = with pkgs; [ util-linux coreutils iproute iputils procps bashInteractive runit ];
in
{
  options = {
    environment = {
      systemPackages = mkOption {
        type = types.listOf types.package;
        default = [];
        example = literalExample "[ pkgs.firefox pkgs.thunderbird ]";
      };
      pathsToLink = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["/"];
        description = "List of directories to be symlinked in <filename>/run/current-system/sw</filename>.";
      };
      extraOutputsToInstall = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "doc" "info" "docdev" ];
        description = "List of additional package outputs to be symlinked into <filename>/run/current-system/sw</filename>.";
      };
    };
    system.path = mkOption {
      internal = true;
    };
  };
  config = {
    environment.systemPackages = requiredPackages;
    environment.pathsToLink = [ "/bin" ];
    system.path = pkgs.buildEnv {
      name = "system-path";
      paths = config.environment.systemPackages;
      inherit (config.environment) pathsToLink extraOutputsToInstall;
      postBuild = ''
        # TODO, any system level caches that need to regenerate
      '';
    };
  };
}
