{ pkgs, lib, config, ... }:

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
  compat = pkgs.runCommand "runit-compat" {} ''
    mkdir -p $out/bin/
    cat << EOF > $out/bin/poweroff
#!/bin/sh
exec runit-init 0
EOF
    cat << EOF > $out/bin/reboot
#!/bin/sh
exec runit-init 6
EOF
    chmod +x $out/bin/{poweroff,reboot}
  '';
in
{
  environment.systemPackages = [ compat pkgs.socat ];
  environment.etc = {
    "runit/1".source = pkgs.writeScript "1" ''
      #!${pkgs.stdenv.shell}
      ${lib.optionalString config.not-os.simpleStaticIp ''
      ip addr add 192.168.56.15 dev eth0
      ip link set eth0 up
      ip route add 192.168.56.0/24 dev eth0
      ''}
      mkdir /bin/
      ln -s ${pkgs.stdenv.shell} /bin/sh

      ${lib.optionalString (config.networking.timeServers != []) ''
        ${pkgs.ntp}/bin/ntpdate ${toString config.networking.timeServers}
      ''}

      # disable DPMS on tty's
      echo -ne "\033[9;0]" > /dev/tty0

      touch /etc/runit/stopit
      chmod 0 /etc/runit/stopit
      ${pkgs.dhcp}/sbin/dhclient eth1
    '';
    "runit/2".source = pkgs.writeScript "2" ''
      #!/bin/sh
      cat /proc/uptime
      exec runsvdir -P /etc/service
    '';
    "runit/3".source = pkgs.writeScript "3" ''
      #!/bin/sh
      echo and down we go
    '';

    "service/sshd/run".source = pkgs.writeScript "sshd_run" ''
      #!/bin/sh
      ${pkgs.openssh}/bin/sshd -f ${sshd_config}
    '';
#    "service/rngd/run".source = pkgs.writeScript "rngd" ''
#      #!/bin/sh
#      export PATH=$PATH:${pkgs.rng_tools}/bin
#      exec rngd
#    '';
    "service/nix/run".source = pkgs.writeScript "nix" ''
      #!/bin/sh
      nix-store --load-db < /nix/store/nix-path-registration
      nix-daemon
    '';
  };
}
