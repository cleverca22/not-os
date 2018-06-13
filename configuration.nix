{ pkgs, ... }:

{
  imports = [ ./qemu.nix ];
  not-os.nix = true;
  not-os.simpleStaticIp = true;
  environment.systemPackages = [ pkgs.utillinux ];
  environment.etc = {
    "ssh/authorized_keys.d/root" = {
      text = ''
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCp81f16cQWHn/LJlgH91TO/E9JvRt5GlWYi7FpXlstlZMsTSBrAbkC4P94VSni27N3NzAxldJ+3D5Vm6OBHmdRtZgeMz3exyveBqoqnYhBTDnHJwNQpyZky4p6WjIKM07a7aw1tZstPmHI2PpmGKc6myZL9F8a4iH06LGPuh1dN8pVg1i5b8a4ppNJQLGTjfYUc7ZJBLUMVrIvIXKocBVXoUEerRsuE5rVX8769ogrZ0hbdbRMcHZDotTGkI2dKxv/V1HDGoIAaTsqedUQxibsoknPSHbZUpWtPcyDX3NMIA+r7G0r1Bzjy0b4GOtbl7BjMJDj2vt+3tu37Kz6n/pZ myrl@myrl-lappy
      '';
      mode = "0444";
    };
  };
}
