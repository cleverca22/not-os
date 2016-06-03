#!@shell@

systemConfig=@systemConfig@
export PATH=@path@/bin/

# Print a greeting.
echo
echo -e "\e[1;32m<<< NotOS Stage 2 >>>\e[0m"
echo

mkdir -p /proc /sys /dev /tmp/ssh /var/log /etc /root /run /nix/var/nix/gcroots
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs devtmpfs /dev
mkdir /dev/pts /dev/shm
mount -t devpts devpts /dev/pts
mount -t tmpfs tmpfs /run
mount -t tmpfs tmpfs /dev/shm

$systemConfig/activate

ip addr add 10.0.2.15 dev eth0
ip link set eth0 up
ip route add 10.0.2.0/24 dev eth0
ip  route add default via 10.0.2.2 dev eth0
#ln -s /run/current-system/etc/ /etc

#@openssh@/bin/sshd -f @sshd_config@ -d

#curl www.google.com
sleep 30
echo o > /proc/sysrq-trigger
stty erase ^H
setsid @shell@ < /dev/ttyS0 > /dev/ttyS0 2>&1
