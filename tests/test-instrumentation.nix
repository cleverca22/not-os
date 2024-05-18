{ pkgs,... }: let
  qemuSerialDevice =
    if with pkgs.stdenv.hostPlatform; isx86 || isLoongArch64 || isMips64 || isRiscV then "ttyS0"
    else if (with pkgs.stdenv.hostPlatform; isAarch || isPower) then "ttyAMA0"
    else throw "Unknown QEMU serial device for system '${pkgs.stdenv.hostPlatform.system}'";
in 

{
  environment.etc = {
    "service/backdoor/run".source = pkgs.writeScript "backdoor_run" ''
      #!/bin/sh
      export USER=root
      export HOME=/root
      export DISPLAY=:0.0

      source /etc/profile

      # Don't use a pager when executing backdoor
      # actions. Because we use a tty, commands like systemctl
      # or nix-store get confused into thinking they're running
      # interactively.
      export PAGER=

      cd /tmp
      exec < /dev/hvc0 > /dev/hvc0
      while ! exec 2> /dev/${qemuSerialDevice}; do sleep 0.1; done
      echo "connecting to host..." >&2
      stty -F /dev/hvc0 raw -echo # prevent nl -> cr/nl conversion
      echo
      PS1= exec /bin/sh
    '';
  };
  boot.initrd.availableKernelModules = [ "virtio_console" ];
  boot.kernelParams = [
     "console=${qemuSerialDevice}"
     "panic=-1"
  ]; 
}
