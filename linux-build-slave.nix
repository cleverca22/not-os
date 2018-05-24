let
  pkgs = import <nixpkgs> {};
  eval = import ./. {
    inherit configuration;
    system = "x86_64-linux";
  };
  configuration = { ... }: {
    imports = [ ./qemu.nix ];
    not-os.nix = true;
    not-os.simpleStaticIp = true;
    environment.systemPackages = with pkgs; [ ];
    environment.etc = {
      "ssh/authorized_keys.d/root" = {
        text = ''
          ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC34wZQFEOGkA5b0Z6maE3aKy/ix1MiK1D0Qmg4E9skAA57yKtWYzjA23r5OCF4Nhlj1CuYd6P1sEI/fMnxf+KkqqgW3ZoZ0+pQu4Bd8Ymi3OkkQX9kiq2coD3AFI6JytC6uBi6FaZQT5fG59DbXhxO5YpZlym8ps1obyCBX0hyKntD18RgHNaNM+jkQOhQ5OoxKsBEobxQOEdjIowl2QeEHb99n45sFr53NFqk3UCz0Y7ZMf1hSFQPuuEC/wExzBBJ1Wl7E1LlNA4p9O3qJUSadGZS4e5nSLqMnbQWv2icQS/7J8IwY0M8r1MsL8mdnlXHUofPlG1r4mtovQ2myzOx clever@nixos
          ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKITUnIETct0d1Ky7iEofM8BV/U9ViuAd72abm26ibhkVKYuLlIvNBtf7+fsyaHR3cc4kmiUz26co4LV2q10HLO7nua7Ry0QhtPvPnpudandB4LbV4ieW1cqcWcPpsM1GssUZhZthbkwLf7h2exojqVj8vqPm5RaBl1eULXaPTldCiSe5ZxNuVbm3qT8Lfc2E3ifKT6A7WqZN00f1+YSnaA9uy0VgVDReDqyujAZaKGUwSa2G8eqzN3guN7VcBZek2p1v1n0EwpFdBxzT3Ncqh5wIYPNn084q5lU13TAjw+tTO7Q059e4HFLaR24w8NT60BrO1dbGYLbjWNri1G3pz root@router
        '';
        mode = "0444";
      };
    };
  };
  runvm = pkgs.writeScript "runner" ''
    #!${pkgs.stdenv.shell}

    exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name buildSlave -m 512 \
      -drive index=0,id=drive1,file=${eval.config.system.build.squashfs},readonly,media=cdrom,format=raw,if=virtio \
      -kernel ${eval.config.system.build.kernel}/bzImage -initrd ${eval.config.system.build.initialRamdisk}/initrd -nographic \
      -append "console=ttyS0 ${toString eval.config.boot.kernelParams} quiet panic=-1" -no-reboot \
      -net nic,vlan=0,model=virtio \
      -net user,vlan=0,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22 \
      -net dump,vlan=0 \
      -device virtio-rng-pci
  '';
in {
  inherit runvm;
}
