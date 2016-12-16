{ ... }:

{
  boot.initrd.kernelModules = [ "virtio" "virtio_pci" "virtio_net" "virtio_rng" "virtio_blk" "virtio_console" ];
}
