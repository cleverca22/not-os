{ pkgs, lib, config, ... }:

let
  sshd_config = pkgs.writeText "sshd_config" ''
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
  environment.systemPackages = [ compat ];
  environment.etc = lib.mkMerge [
    {
      "runit/1".source = pkgs.writeScript "1" ''
        #!${pkgs.runtimeShell}

        ED25519_KEY="/etc/ssh/ssh_host_ed25519_key"

        if [ ! -f $ED25519_KEY ]; then
          ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f $ED25519_KEY -N ""
        fi

        ${lib.optionalString config.not-os.simpleStaticIp ''
        ip addr add 10.0.2.15 dev eth0
        ip link set eth0 up
        ip route add 10.0.2.0/24 dev eth0
        ip  route add default via 10.0.2.2 dev eth0
        ''}
        mkdir /bin/
        ln -s ${pkgs.runtimeShell} /bin/sh

        ${lib.optionalString (config.networking.timeServers != []) ''
          ${pkgs.ntp}/bin/ntpdate ${toString config.networking.timeServers}
        ''}

        # disable DPMS on tty's
        echo -ne "\033[9;0]" > /dev/tty0

        touch /etc/runit/stopit
        chmod 0 /etc/runit/stopit
        ${if true then "" else "${pkgs.dhcpcd}/sbin/dhcpcd"}
      '';
      "runit/2".source = pkgs.writeScript "2" ''
        #!${pkgs.runtimeShell}
        cat /proc/uptime
        exec runsvdir -P /etc/service
      '';
      "runit/3".source = pkgs.writeScript "3" ''
        #!${pkgs.runtimeShell}
        echo and down we go
      '';
      "service/sshd/run".source = pkgs.writeScript "sshd_run" ''
        #!${pkgs.runtimeShell}
        ${pkgs.openssh}/bin/sshd -f ${sshd_config}
      '';
      "service/nix/run".source = pkgs.writeScript "nix" ''
        #!${pkgs.runtimeShell}
        nix-store --load-db < /nix/store/nix-path-registration
        nix-daemon
      '';
    }
    (lib.mkIf config.not-os.rngd {
      "service/rngd/run".source = pkgs.writeScript "rngd" ''
        #!${pkgs.runtimeShell}
        export PATH=$PATH:${pkgs.rng-tools}/bin
        exec rngd -r /dev/hwrng
      '';
    })
  ];
}
