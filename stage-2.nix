{ lib, pkgs, config, ... }:

with lib;

{
  options = {
    boot = {
      devSize = mkOption {
        default = "5%";
        example = "32m";
        type = types.str;
      };
      devShmSize = mkOption {
        default = "50%";
        example = "256m";
        type = types.str;
      };
      runSize = mkOption {
        default = "25%";
        example = "256m";
        type = types.str;
       };
    };
  };
  config = {
    system.build.bootStage2 = pkgs.replaceVarsWith {
      src = ./stage-2-init.sh;
      isExecutable = true;
      replacements = {
        path = config.system.path;
        inherit (pkgs) runtimeShell;
        # null keeps @systemConfig@ in the file; toplevel fills it in later.
        systemConfig = null;
      };
    };
  };
}
