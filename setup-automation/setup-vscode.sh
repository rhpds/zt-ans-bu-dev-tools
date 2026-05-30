#!/bin/bash
set -euxo pipefail

retry() {
    for i in {1..3}; do
        echo "Attempt $i: $2"
        if $1; then
            return 0
        fi
        [ $i -lt 3 ] && sleep 5
    done
    echo "Failed after 3 attempts: $2"
    exit 1
}

## Register with Satellite for lab-specific repos
retry "curl -k -L https://${SATELLITE_URL}/pub/katello-server-ca.crt -o /etc/pki/ca-trust/source/anchors/${SATELLITE_URL}.ca.crt"
retry "update-ca-trust"
retry "rpm -Uhv https://${SATELLITE_URL}/pub/katello-ca-consumer-latest.noarch.rpm"
retry "subscription-manager register --org=${SATELLITE_ORG} --activationkey=${SATELLITE_ACTIVATIONKEY}"

## Runtime security settings
setenforce 0
systemctl stop firewalld

## Generate SSH key for rhel user
USER="rhel"
RHEL_SSH_DIR="/home/${USER}/.ssh"
RHEL_PRIVATE_KEY="${RHEL_SSH_DIR}/id_rsa"

if [ ! -f "$RHEL_PRIVATE_KEY" ]; then
    echo "Creating SSH key for ${USER} user..."
    sudo -u ${USER} mkdir -p ${RHEL_SSH_DIR}
    sudo -u ${USER} chmod 700 ${RHEL_SSH_DIR}
    sudo -u ${USER} ssh-keygen -t rsa -b 4096 -C "${USER}@$(hostname)" -f ${RHEL_PRIVATE_KEY} -N "" -q
    sudo -u ${USER} chmod 600 ${RHEL_SSH_DIR}/id_rsa*
fi

## Start code-server
systemctl start code-server
sleep 15
