#!/bin/sh

# setup cloud init
/sbin/setup-cloud-init
# set timezone
cp /usr/share/zoneinfo/UTC /etc/localtime
apk del tzdata
echo "UTC" >/etc/timezone
# allow AllowTcpForwarding (SOCKS5)
sed -i -r "s/^AllowTcpForwarding(.*)$/AllowTcpForwarding yes/" /etc/ssh/sshd_config

# networking
ln -s networking /etc/init.d/net.lo
ln -s networking /etc/init.d/net.eth0
ln -s networking /etc/init.d/net.eth1

# start network
rc-update add net.eth0 default
rc-update add net.eth1 default
rc-update add net.lo boot

# Enable openssh server
rc-update add sshd default

cat > /etc/resolv.conf <<-EOF
# quad9.net
nameserver 9.9.9.9
nameserver 149.112.112.112
EOF

# Create do-init OpenRC service
cat > /etc/init.d/fix-resolvconf <<-EOF
#!/sbin/openrc-run
depend() {
    need net.eth0
}

start() {
    ebegin "Starting \$RC_SVCNAME"
    sed -n -r "s/.*dns-(nameserver)s ([0-9.]*?) ([0-9.]*?).*\$/\1 \2\n\1 \3/p" /etc/network/interfaces | resolvconf -a eth0
    resolvconf -c eth0
    eend \$?
}
EOF

# Make fix-resolvconf and service executable
chmod +x /etc/init.d/fix-resolvconf

# enable service
rc-update add fix-resolvconf default

# change motd
printf "Welcome to Alpine.\\nBuild at %s %s with alpine-droplet scripts.\\n" $(date -u "+%Y.%m.%d %H:%M") >/etc/motd

# sshguard
cat >/etc/sshguard.conf <<-EOF
#### REQUIRED CONFIGURATION ####
# Full path to backend executable (required, no default)
BACKEND='/usr/libexec/sshg-fw-nft-sets'
#### OPTIONS ####
# Block attackers when their cumulative attack score exceeds THRESHOLD.
# Most attacks have a score of 10. (optional, default 30)
THRESHOLD=30

# Block attackers for initially BLOCK_TIME seconds after exceeding THRESHOLD.
# Subsequent blocks increase by a factor of 1.5. (optional, default 120)
BLOCK_TIME=120

# Remember potential attackers for up to DETECTION_TIME seconds before
# resetting their score. (optional, default 1800)
DETECTION_TIME=1800

# IP addresses listed in the WHITELIST_FILE are considered to be
# friendlies and will never be blocked.
WHITELIST_FILE=/etc/sshguard.whitelist

# Blacklist threshold and file name
BLACKLIST_FILE=200:/var/db/sshguard.blacklist.db

# IPv6 subnet size to block. Defaults to a single address, CIDR notation. (optional, default to 128)
IPV6_SUBNET=64
# IPv4 subnet size to block. Defaults to a single address, CIDR notation. (optional, default to 32)
IPV4_SUBNET=24
FILES='/var/log/messages'
EOF

cat >/etc/sshguard.whitelist <<-EOF
# To see more examples, please see
# /usr/share/doc/sshguard/examples/whitelistfile.example

# Address blocks in CIDR notation
127.0.0.0/8
::1/128
10.0.0.0/8
EOF

# automatic start
rc-update add sshguard default
