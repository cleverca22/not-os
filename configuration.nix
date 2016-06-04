{ pkgs, ... }:

{
  environment.etc = {
    "service/toxvpn/run".source = pkgs.writeScript "toxvpn_run" ''
      #!/bin/sh
      mkdir -p /run/toxvpn /var/lib/toxvpn
      rm /run/toxvpn/control || true
      chown toxvpn /var/lib/toxvpn /run/toxvpn
      ${pkgs.toxvpn}/bin/toxvpn -i 192.168.123.123 -l /run/toxvpn/control -u toxvpn
    '';
    "ssh/authorized_keys.d/root" = {
      text = ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC34wZQFEOGkA5b0Z6maE3aKy/ix1MiK1D0Qmg4E9skAA57yKtWYzjA23r5OCF4Nhlj1CuYd6P1sEI/fMnxf+KkqqgW3ZoZ0+pQu4Bd8Ymi3OkkQX9kiq2coD3AFI6JytC6uBi6FaZQT5fG59DbXhxO5YpZlym8ps1obyCBX0hyKntD18RgHNaNM+jkQOhQ5OoxKsBEobxQOEdjIowl2QeEHb99n45sFr53NFqk3UCz0Y7ZMf1hSFQPuuEC/wExzBBJ1Wl7E1LlNA4p9O3qJUSadGZS4e5nSLqMnbQWv2icQS/7J8IwY0M8r1MsL8mdnlXHUofPlG1r4mtovQ2myzOx clever@nixos
      '';
      mode = "0444";
    };
  };
}
