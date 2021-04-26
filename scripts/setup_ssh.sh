#!/usr/bin/env bash

SSH_CONF_PATH="/etc/ssh/sshd_config"

sed -i "/^UseDNS/d" ${SSH_CONF_PATH}
sed -i "/^GSSAPIAuthentication/d" ${SSH_CONF_PATH}
sed -i "/^PermitRootLogin/d" ${SSH_CONF_PATH}
sed -i "/^PasswordAuthentication/d" ${SSH_CONF_PATH}
sed -i "/^PermitEmptyPasswords/d" ${SSH_CONF_PATH}
sed -i "/^PubkeyAuthentication/d" ${SSH_CONF_PATH}
sed -i "/^AuthorizedKeysFile/d" ${SSH_CONF_PATH}
sed -i "/^ClientAliveInterval/d" ${SSH_CONF_PATH}
sed -i "/^AuthorizedKeysFile/d" ${SSH_CONF_PATH}
sed -i "/^AuthorizedKeysFile/d" ${SSH_CONF_PATH}

echo "UseDNS no" >> ${SSH_CONF_PATH}
echo "GSSAPIAuthentication no" >> ${SSH_CONF_PATH}
echo "PermitRootLogin yes" >> ${SSH_CONF_PATH}
echo "PasswordAuthentication no" >> ${SSH_CONF_PATH}
echo "PermitEmptyPasswords no" >> ${SSH_CONF_PATH}
echo "PubkeyAuthentication yes" >> ${SSH_CONF_PATH}
echo "AuthorizedKeysFile .ssh/authorized_keys" >> ${SSH_CONF_PATH}
echo "ClientAliveInterval 360" >> ${SSH_CONF_PATH}
echo "ClientAliveCountMax 0" >> ${SSH_CONF_PATH}
echo "Protocol 2" >> ${SSH_CONF_PATH}
