#!/bin/bash
set -euxo pipefail

retry() {
    local cmd="$1"
    local desc="${2:-$cmd}"
    for i in {1..3}; do
        echo "Attempt $i: $desc"
        if eval "$cmd"; then
            return 0
        fi
        [ $i -lt 3 ] && sleep 5
    done
    echo "Failed after 3 attempts: $desc"
    exit 1
}

## Disruptive operations first — before code-server has active connections
setenforce 0 || true
systemctl stop firewalld || true

## Register with Satellite for lab-specific repos
retry "curl -k -L https://${SATELLITE_URL}/pub/katello-server-ca.crt -o /etc/pki/ca-trust/source/anchors/${SATELLITE_URL}.ca.crt" "Download Satellite CA cert"
retry "update-ca-trust" "Update CA trust"
retry "rpm -Uhv https://${SATELLITE_URL}/pub/katello-ca-consumer-latest.noarch.rpm || true" "Install katello consumer RPM"
retry "subscription-manager register --org=${SATELLITE_ORG} --activationkey=${SATELLITE_ACTIVATIONKEY} || true" "Register with Satellite"

## Generate SSH key for rhel user
USER="rhel"
RHEL_SSH_DIR="/home/${USER}/.ssh"
RHEL_PRIVATE_KEY="${RHEL_SSH_DIR}/id_rsa"

if [ ! -f "$RHEL_PRIVATE_KEY" ]; then
    echo "Creating SSH key for ${USER} user..."
    sudo -u "${USER}" mkdir -p "${RHEL_SSH_DIR}"
    sudo -u "${USER}" chmod 700 "${RHEL_SSH_DIR}"
    sudo -u "${USER}" ssh-keygen -t rsa -b 4096 -C "${USER}@$(hostname)" -f "${RHEL_PRIVATE_KEY}" -N "" -q
    sudo -u "${USER}" chmod 600 "${RHEL_SSH_DIR}"/id_rsa*
fi

## Verify code-server is running (image starts it on boot with correct config,
## don't restart as it would kill active browser connections)
if systemctl is-active --quiet code-server; then
    echo "code-server is already running"
else
    systemctl start code-server
    for i in $(seq 1 30); do
        if curl -sf http://localhost:8080/healthz > /dev/null 2>&1; then
            echo "code-server is ready"
            break
        fi
        sleep 2
    done
fi
