{ lib, pkgs, config, ... }:

with lib;

let
  sshd_config = pkgs.writeText "sshd_config" ''
    HostKey /etc/ssh/ssh_host_rsa_key
    HostKey /etc/ssh/ssh_host_ed25519_key
    Port 22
    PidFile /run/sshd.pid
    Protocol 2
    PermitRootLogin yes
    PasswordAuthentication yes
    AuthorizedKeysFile /etc/ssh/authorized_keys.d/%u
  '';
in
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
    system.build.bootStage2 = pkgs.substituteAll {
      src = ./stage-2-init.sh;
      isExecutable = true;
      path = config.system.path;
      openssh = pkgs.openssh;
      sshd_config = sshd_config;
    };
  };
}
