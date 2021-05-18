#!/bin/bash

# Load terraform vars
while [ ! -f /run/scripts/vars ]; do sleep 1; done
source /run/scripts/vars

# Setup swap using Azure device block
sed -i "s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/" /etc/waagent.conf
sed -i "s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=${vm_hana_swap_size}/" /etc/waagent.conf
systemctl restart waagent.service
 
# Wait for disks
disks=(c d e f g h i j k l m n o p q r s t u v w x y z)
hana_paths=(${disks_paths})
if [ ${disks_number} -gt 0 ]; then
  for i in ${!hana_paths[@]}; do
    echo -n "Waiting for disk /dev/sd${disks[i]}... "
    while [ ! -b /dev/sd${disks[i]} ]; do sleep 1; done
    echo "[ OK ]"
  done
  rescan-scsi-bus.sh
fi

# Format and mount disks
for i in "${!hana_paths[@]}"; do
  [ -b /dev/sd${disks[i]}1 ] && continue
  echo "Partitioning disk /dev/sd${disks[i]}..."
  parted --script /dev/sd${disks[i]} mklabel gpt mkpart primary xfs 0% 100%
  partprobe /dev/sd${disks[i]}
  echo "Formating disk /dev/sd${disks[i]}1 as XFS..."
  mkfs.xfs /dev/sd${disks[i]}1
  [ ! -d ${hana_paths[i]} ] && mkdir -p ${hana_paths[i]}
  echo "Mounting partition/dev/sd${disks[i]}1 at ${hana_paths[i]}..."
  mount /dev/sd${disks[i]}1 ${hana_paths[i]}
  uuid=$(lsblk -n -f /dev/sd${disks[i]}1 -o UUID)
  echo "Adding mouting entry ${hana_paths[i]} to /etc/fstab..."
  echo "UUID=\"${uuid}\"  ${hana_paths[i]}  xfs  defaults,noatime  0  0" >> /etc/fstab
done

# Register system in SCC
SUSEConnect -r ${vm_hana_reg_code} -e ${vm_hana_reg_email}

# Refresh repos
zypper ref

# Enable SUSE modules
SUSEConnect -p sle-module-public-cloud/15.2/x86_64

# Update system
zypper -n up -l

# Install SUSE packages for HANA
zypper -n in -t pattern sap-hana
zypper -n in saphanabootstrap-formula
zypper -n in salt-minion

# Mount HANA Media
[ ! -d ${hana_media_local} ] && mkdir -p ${hana_media_local}
[ ! -d "/etc/smbcredentials" ] && mkdir -p /etc/smbcredentials
smbcredfile="/etc/smbcredentials/${storage_account}.cred"
cat <<EOF > ${smbcredfile}
username=${storage_account}
password=${hana_media_key}
EOF

chmod 600 ${smbcredfile}
if [ ${hana_media_add_fstab} = true ]; then
  echo "//${storage_account}.file.core.windows.net${hana_media_storage}  ${hana_media_local}  cifs  nofail,vers=3.0,credentials=${smbcredfile},dir_mode=0777,file_mode=0777,serverino" >> /etc/fstab
  mount ${hana_media_local}
else
  mount -t cifs //${storage_account}.file.core.windows.net${hana_media_storage} ${hana_media_local} -o vers=3.0,credentials=${smbcredfile},dir_mode=0777,file_mode=0777,serverino
fi

# Configure salt for HANA deployment
cat <<EOF >/etc/salt/minion.d/hana.conf
file_roots:
  base:
    - /srv/salt
    - /usr/share/salt-formulas/states
EOF

[ ! -d /srv/pillar ] && mkdir -p /srv/pillar
cat <<EOF >/srv/pillar/top.sls
base:
  '*':
    - hana
EOF

exporter=""
if [ ${hana_monitoring_enabled} = true ]; then
exporter="""      exporter:
        exposition_port: ${monit_exposition_port}
        multi_tenant: ${monit_multi_tenant}
        user: \"${monit_user}\"
        password: \"${hana_system_user_password}\"
        port: 3${hana_instance}13
        timeout: ${monit_timeout}
"""
fi 

cat <<EOF > /srv/pillar/hana.sls
hana:
  install_packages: ${hana_install_packages}
  saptune_solution: "HANA"
  software_path: "${hana_software_path}"
  ha_enabled: false
  monitoring_enabled: ${hana_monitoring_enabled}

  nodes:
    - host: "${vm_hana_name}"
      sid: "${hana_sid}"
      instance: "${hana_instance}"
      password: "${hana_password}"
      install:
        root_user: "root"
        root_password: "${admin_password}"
        system_user_password: "${hana_system_user_password}"
        sapadm_password: "${hana_sapadm_password}"
${exporter}
EOF

# Run salt for SAP HANA deployment
salt-call --local saltutil.sync_all
salt-call --local -l profile state.apply hana
