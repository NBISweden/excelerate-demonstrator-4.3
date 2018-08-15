#!/bin/bash

# Script to deploy a gridftp endpoint on a CentOS 7 machine
# with letsencrypt server certificate and a user mapping.
#
# Usage: centos-gridftp-rw.sh CERTIFICATEDN EMAIL
# 

# run as root
if ((EUID != 0)); then
    exec sudo "$0" "$1" "$2"
    exit
fi

# set your email address (needed by letsencrypt)
EMAIL=$2

# enable yum repositories
yum install -y epel-release
cd /etc/yum.repos.d/
curl -O http://repository.egi.eu/sw/production/cas/1/current/repo-files/EGI-trustanchors.repo
curl -O http://fts-repo.web.cern.ch/fts-repo/fts3-continuous-el7.repo

# install trust anchors
yum install -y -q ca-policy-egi-core ca_RCauth-Pilot-ICA-G1 ca_letsencrypt

# install certbot
yum install -y -q certbot

# install gridftp server
yum install -y -q openssl globus-gridftp-server globus-gridftp-server-progs

# server certificate

# first find domain name of server
DOMAIN=`curl -s https://myhostname.net/ | grep Hostname | sed -E 's/Hostname:\s+([^[:space:]]+)\s*.*/\1/'`

# obtain letsencrypt certificate
/usr/bin/certbot certonly --non-interactive --renew-by-default --standalone \
    --post-hook="chmod 0400 /etc/letsencrypt/live/${DOMAIN}/privkey.pem" \
    -m "${EMAIL}" --agree-tos \
    -d "${DOMAIN}" \
    --preferred-challenges http-01

# create symlinks so that gridftpd use these certificates
if [[ ! -f "/etc/grid-security/hostcert.pem" ]]; then
    ln -s "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" "/etc/grid-security/hostcert.pem"
    ln -s "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" "/etc/grid-security/hostkey.pem"
fi

# set up and configure gridftp

# create gridftp system account
useradd -r -s /sbin/nologin gridftp

# map certificate subject to gridftp user
echo "\"$1\" gridftp" >> /etc/grid-security/grid-mapfile

# create data directory
mkdir -p /srv/data
chown gridftp:gridftp /srv/data

# create 1GB test file
fallocate -l 1g /srv/data/1g.dat

# create gridftp configuration file
cat <<EOF > /etc/gridftp.conf
\$GLOBUS_ERROR_VERBOSE 1
\$GLOBUS_TCP_PORT_RANGE 50000,51000
\$GLOBUS_HOSTNAME $DOMAIN

# port
port 2811

log_level ALL
log_single /var/log/gridftp.log
log_transfer /var/log/gridftp-transfer.log
restrict_paths /srv/data,/dev/zero,/dev/null
# add UDT support
dc_whitelist udt,gsi,tcp
EOF

# start gridftp server
systemctl start globus-gridftp-server 

