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
      postBootCommands = mkOption {
        default = "";
        example = "rm -f /var/log/messages";
        type = types.lines;
        description = lib.mdDoc ''
          Shell commands to be executed just before runit is started.
        '';
      };
    };
    networking.hostName = mkOption {
      default = "";
      type = types.strMatching
        "^$|^[[:alnum:]]([[:alnum:]_-]{0,61}[[:alnum:]])?$";
    };
  };
  config = {
    system.build.bootStage2 = pkgs.substituteAll {
      src = ./stage-2-init.sh;
      isExecutable = true;
      path = config.system.path;
      inherit (pkgs) runtimeShell;
      postBootCommands = pkgs.writeText "local-cmds" ''
        ${config.boot.postBootCommands}
      '';
    };
  };
}
