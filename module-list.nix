let
  nixos = path: {modulesPath, ...}: {
    imports = [(modulesPath + path)];
  };
in [
  ./base.nix
  ./system-path.nix
  ./stage-1.nix
  ./stage-2.nix
  ./runit.nix
  ./ipxe.nix
  ./systemd-compat.nix
  (nixos "/system/etc/etc.nix")
  (nixos "/system/activation/activation-script.nix")
  (nixos "/misc/nixpkgs.nix")
  (nixos "/system/boot/kernel.nix")
  (nixos "/misc/assertions.nix")
  (nixos "/misc/lib.nix")
  (nixos "/config/sysctl.nix")
]
