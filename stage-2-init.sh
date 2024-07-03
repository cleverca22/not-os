#!@runtimeShell@

systemConfig=@systemConfig@
export PATH=@path@/bin/

# Print a greeting.
echo
echo -e "\e[1;32m<<< NotOS Stage 2 >>>\e[0m"
echo

mkdir -p /proc /sys /dev /tmp /var/log /etc /root /run /nix/var/nix/gcroots
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs devtmpfs /dev
mkdir /dev/pts /dev/shm
mount -t devpts devpts /dev/pts
mount -t tmpfs tmpfs /run
mount -t tmpfs tmpfs /dev/shm

$systemConfig/activate

# Run any user-specified commands.
@runtimeShell@ @postBootCommands@

exec runit
