#!/bin/bash

# Load terraform vars
while [ ! -f /run/scripts/vars ]; do sleep 1; done
source /run/scripts/vars

# Setup swap using Azure device block
sed -i "s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/" /etc/waagent.conf
sed -i "s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=${vm_swap_size}/" /etc/waagent.conf
systemctl restart waagent.service
 
# Register system in SCC
SUSEConnect -r ${vm_reg_code} -e ${vm_reg_email}

# Refresh repos
zypper ref

# Enable SUSE modules
SUSEConnect -p sle-module-public-cloud/15.2/x86_64

# Update system
zypper -n up -l

# Install SUSE packages for SAP Application
zypper -n in -t pattern sap_server sap-nw ha_sles
zypper -n in habootstrap-formula sapnwbootstrap-formula \
  salt-minion socat resource-agents fence-agents \
  python3-azure-mgmt-compute python3-azure-identity \
  sap-suse-cluster-connector patch

# Mount HANA Media
[ ! -d ${sap_media_local} ] && mkdir -p ${sap_media_local}
[ ! -d "/etc/smbcredentials" ] && mkdir -p /etc/smbcredentials
smbcredfile="/etc/smbcredentials/${storage_account}.cred"
cat <<EOF > ${smbcredfile}
username=${storage_account}
password=${sap_media_key}
EOF

chmod 600 ${smbcredfile}
if [ ${sap_media_add_fstab} = true ]; then
  echo "//${storage_account}.file.core.windows.net${sap_media_storage}  ${sap_media_local}  cifs  nofail,vers=3.0,credentials=${smbcredfile},dir_mode=0777,file_mode=0777,serverino" >> /etc/fstab
  mount ${sap_media_local}
else
  mount -t cifs //${storage_account}.file.core.windows.net${sap_media_storage} ${sap_media_local} -o vers=3.0,credentials=${smbcredfile},dir_mode=0777,file_mode=0777,serverino
fi

#TODO: Ajustar Variáveis e converter blocos para usar netapp
# mkdir /sapmnt
# mkdir /usr/sap
# mount -t nfs -o vers=3 10.0.1.6:/var/sapmnt /sapmnt
# mount -t nfs -o vers=3 10.0.1.6:/var/sap /usr/sap
# rm -rf /sapmnt/*
# rm -rf /usr/sap/*
#Fix para instalação funcionar
# mkdir -p /usr/sap/HA1/SYS/exe
# mkdir -p /usr/sap/HA1/ERS10/exe
useradd sapadm

# Apply patch to azure_fence.py
echo "Applying patch to azure_fence.py library ..."
cat <<EOF > /tmp/azure_fence.py.patch
--- azure_fence.py	2021-02-26 19:21:51.000000000 +0000
+++ azure_fence.py.new	2021-04-11 23:17:59.543732484 +0000
@@ -292,19 +292,19 @@
         from msrestazure.azure_active_directory import MSIAuthentication
         credentials = MSIAuthentication()
     elif cloud_environment:
-        from azure.common.credentials import ServicePrincipalCredentials
-        credentials = ServicePrincipalCredentials(
+        from azure.identity import ClientSecretCredential
+        credentials = ClientSecretCredential(
             client_id = config.ApplicationId,
-            secret = config.ApplicationKey,
-            tenant = config.Tenantid,
+            client_secret = config.ApplicationKey,
+            tenant_id = config.Tenantid,
             cloud_environment=cloud_environment
         )
     else:
-        from azure.common.credentials import ServicePrincipalCredentials
-        credentials = ServicePrincipalCredentials(
+        from azure.identity import ClientSecretCredential
+        credentials = ClientSecretCredential(
             client_id = config.ApplicationId,
-            secret = config.ApplicationKey,
-            tenant = config.Tenantid
+            client_secret = config.ApplicationKey,
+            tenant_id = config.Tenantid
         )
 
     return credentials
EOF
unix2dos /tmp/azure_fence.py.patch
patch --binary /usr/share/fence/azure_fence.py /tmp/azure_fence.py.patch

vm_names=(${vm_names})
vm_ips=(${vm_ips})
# Configure salt for SAP deployment
cat <<EOF >/etc/salt/minion.d/sap.conf
file_roots:
  base:
    - /srv/salt
    - /usr/share/salt-formulas/states
EOF

[ ! -d /srv/pillar ] && mkdir -p /srv/pillar
cat <<EOF >/srv/pillar/top.sls
base:
  '*':
    - cluster
    - netweaver
EOF

cat <<EOF > /srv/pillar/cluster.sls
cluster:
  # Cluster name
  name: hacluster
  init: ${vm_names[0]}
  watchdog:
    module: softdog
    device: /dev/watchdog
  interface: eth0
  unicast: ${cluster_unicast}
  admin_ip: ${lb_private_ip}
  monitoring_enabled: ${enable_monitoring}
  corosync:
    totem:
      token: 30000
      interface:
        bindnetaddr: ${vm_ip_network}
    quorum:
      expected_votes: ${vm_number}
  hacluster_password: "${cluster_password}"
  sshkeys:
    password: "${admin_password}"
  configure:
    properties:
      stonith-enabled: true
      stonith-timeout: 300
      concurrent-fencing: true
      no-quorum-policy: "ignore"
      stonith-action: "off"
    rsc_defaults:
      resource-stickiness: 1000
      migration-threshold: 5000
      failure-timeout: 600
    op_defaults:
      timeout: 600
      record-pending: true
EOF

# Pillar para instalação do netweaver

cat <<EOF > /srv/pillar/netweaver.sls
netweaver:
  # optional: Install required packages to install SAP Netweaver (true by default)
  # If set to false, these packages must be installed before the formula execution manually
  # install_packages: true

  virtual_addresses:
    ${vm_ips[0]}: ${vm_names[0]}
    ${vm_ips[1]}: ${vm_names[1]}
    ${sap_hana_ip}: ${sap_hana_host}
    ${sap_ascs_vip_address}: ${sap_ascs_vip_hostname}
    ${sap_ers_vip_address}: ${sap_ers_vip_hostname}
  
  # Create sidadm and sapsys user/group.
  # If this entry exists the user and group will be created before the installation, not otherwise
  sidadm_user:
    uid: ${sidadm_user_uid}
    gid: ${sidadm_user_guid}
  # sid_adm_password is optional, master password will be used as default, if value is not defined
  sid_adm_password: ${sid_adm_password}
  # sap_adm_password is optional, master password will be used as default, if value is not defined
  sap_adm_password: ${sap_adm_password}
  # Master password is used for all the SAP users that are created
  master_password: ${master_password}

  # Local path where sapmnt data is stored. This is a local path. This folder can be mounted in a NFS share
  # using sapmnt_inst_media
  # /sapmnt by default
  sapmnt_path: ${sapmnt_path}
  # Define NFS share where sapmnt and SYS folder will be mounted. This NFS share must already have
  # the sapmnt and usrsapsys folders
  # If it is not used or empty string is set, the sapmnt and SYS folder are created locally
  sapmnt_inst_media: ${sapmnt_inst_media}
  # Clean /sapmnt/{sid} and /usr/sap/{sid}/SYS content. It will only work if ASCS node is defined.
  # True by default. It only works if a NFS share is defined in sapmnt_inst_media
  clean_nfs: True
  # Used to connect to the nfs share
  # nfs_version: nfs4
  # nfs_options: defaults
  # Use the next options for AWS for example
  # nfs_options: rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2

  # Specify the path to already extracted SWPM installer folder
  swpm_folder: ${swpm_folder}
  # Or specify the path to the sapcar executable & SWPM installer sar archive, to extract the installer
  # The sar archive will be extracted to a subfolder SWPM, under nw_extract_dir (optional, by default /sapmedia_extract/NW/SWPM)
  # Make sure to use the latest/compatible version of sapcar executable, and that it has correct execute permissions
  # sapcar_exe_file: your_sapcar_exe_file_absolute_path
  # swpm_sar_file: your_swpm_sar_file_absolute_path
  # nw_extract_dir: location_to_extract_nw_media_absolute_path
  sapexe_folder: 	${sapexe_folder}
  # Folder where the installation files are stored. /tmp/swpm_unattended by default. Set None to use
  # SAP default folders (it will only work with ASCS and ERS).
  # This folder content will be removed before the installation so be extra careful!
  installation_folder: /tmp/swpm_unattended
  # DB/PAS/AAS instances require additional DVD folders like NW Export or HDB Client folder
  # Provide the absolute path to software folder or archives with additional SAP software needed to install netweaver
  additional_dvds:
    - ${additional_dvds}


  # Enable operations in ASCS and ERS to set HA environment correctly (HA cluster is not installed)
  ha_enabled: True

  # syctl options. Some system options must be update for optimal usage, like tcp keepalive parameter
  # sysctl values based on:
  # https://launchpad.support.sap.com/#/notes/1410736
  # https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-suse#2d6008b0-685d-426c-b59e-6cd281fd45d7
  # Do not touch if not sure about the changes
  #sysctl_values:
  #  net.ipv4.tcp_keepalive_time: 300
  #  net.ipv4.tcp_keepalive_intvl: 75
  #  net.ipv4.tcp_keepalive_probes: 9

  # saptune solution to apply to all nodes ( by default nothing is applied)
  # you can also use this to a single node if need to differ. see host hacert02
  # Warning: only a unique solution can exist into a node.
  saptune_solution: 'NETWEAVER'

  # Information about the already deployed HANA Database
  # This entry is mandatory if DB/PAS/AAS are to be installed

  hana:
    host: ${sap_hana_ip}
    sid: ${sap_hana_sid}
    instance: ${sap_hana_instance}
    password: ${sap_hana_password}

  # Information about the Schema created during DB installation and used by PAS/AAS
  # If this dictionary is not set default values will be used
  #schema:
  #  name: schema_name
  #  password: your_password

  # The installed product id. If some particular node has its own product_id that one will have the preference
  # Just put the product id ommiting the initial part like NW_ABAP_ASCS, NW_ERS, etc
  # Examples
  product_id: NW750.HDB.ABAPHA
  # For non HA environments
  #product_id: NW750.HDB.ABAP
  # For HA S4/HANA
  #product_id: S4HANA1709.CORE.HDB.ABAPHA

  # optional: enables monitoring via sap_host_exporter (disabled by default)
  # the exporter will be installed and configured in all the nodes
  monitoring_enabled: true

  nodes:
    - host: ${vm_names[0]}
      virtual_host: ${sap_ascs_vip_hostname}
      # virtual_host_interface: eth1 # eth0 by default
      # virtual_host_mask: 32 # 24 by default
      sid: ${sap_ascs_instance_sid}
      instance: ${sap_ascs_instance_id}
      root_user: ${sap_ascs_root_user}
      root_password: ${sap_ascs_root_password}
      # Set the shared disk used in HA environments. Skip this parameter in non HA environments
      # shared_disk_dev: /dev/sbd
      # Or if a nfs share is used to manage the HA mounting point, like in the cloud providers
      #shared_disk_dev: your_nfs_share_SID_folder/ASCS
      # Init the shared disk. Only used if a shared disk is provided, not in nfs share cases
      # init_shared_disk: True
      # Set an specific product id. In this case the initial part of the code is accepted too, even though it's recommend to use the 1st example option
      # product_id: NW750.HDB.ABAPHA
      product_id: NW750.HDB.ABAP
      # SAP:NETWEAVER:750
      #product_id: NW_ABAP_ASCS:S4HANA1709.CORE.HDB.ABAPHA
      sap_instance: ascs

    - host: ${vm_names[1]}
      virtual_host: ${sap_ers_vip_hostname}
      sid: ${sap_ers_instance_sid}
      instance: ${sap_ers_instance_id}
      saptune_solution: 'MAXDB'
      root_user: ${sap_ers_root_user}
      root_password: ${sap_ers_root_password}
      # Set the shared disk used in HA environments. Skip this parameter in non HA environments
      # shared_disk_dev: /dev/sbd
      # If a nfs share is used to manage the HA mounting point, like in the cloud
      #shared_disk_dev: your_nfs_share_SID_folder/ERS
      sap_instance: ers
EOF


#TODO: Make  a PR for suse-nwbootstrap

cat <<EOF > /usr/share/salt-formulas/states/netweaver/ha_cluster.sls
{%- from "netweaver/map.jinja" import netweaver with context -%}
{% set host = grains['host'] %}

{% for node in netweaver.nodes if netweaver.ha_enabled and host == node.host and node.sap_instance in ['ascs', 'ers'] %}

{% set instance = '{:0>2}'.format(node.instance) %}
{% set instance_name = node.sid~'_'~instance %}
{% set instance_folder = node.sap_instance.upper()~instance %}
{% set profile_file = '/usr/sap/'~node.sid.upper()~'/SYS/profile/'~node.sid.upper()~'_'~instance_folder~'_'~node.virtual_host %}

install_suse_connector:
  pkg.installed:
    - name: sap-suse-cluster-connector
    - require:
      - netweaver_install_{{ instance_name }}

wait_until_systems_installed:
  netweaver.check_instance_present:
{% if node.sap_instance.lower() == 'ascs' %}
    - name: ENQREP
{% else %}
    - name: MESSAGESERVER
{% endif %}
    - dispstatus: GREEN
    - sid: {{ node.sid.lower() }}
    - inst: {{ instance }}
    - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
    - retry:
        attempts: 20
        interval: 30
    - require:
      - netweaver_install_{{ instance_name }}

update_sapservices_{{ instance_name }}:
    netweaver.sapservices_updated:
      - name: {{ node.sap_instance.lower() }}
      - sid: {{ node.sid.lower() }}
      - inst: {{ instance }}
      - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
      - require:
        - netweaver_install_{{ instance_name }}

stop_sap_instance_{{ instance_name }}:
  module.run:
    - name: netweaver.execute_sapcontrol
    - function: 'Stop'
    - sid: {{ node.sid.lower() }}
    - inst: {{ instance }}
    - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
    - test.sleep:
      - length: 15
    - require:
      - netweaver_install_{{ instance_name }}

stop_sap_instance_service_{{ instance_name }}:
  module.run:
    - name: netweaver.execute_sapcontrol
    - function: 'StopService'
    - sid: {{ node.sid.lower() }}
    - inst: {{ instance }}
    - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
    - test.sleep:
      - length: 15
    - require:
      - netweaver_install_{{ instance_name }}

add_ha_scripts_{{ instance_name }}:
  file.append:
    - name: {{ profile_file }}
    - text: |
        #-----------------------------------------------------------------------
        # HA script connector
        #-----------------------------------------------------------------------
        service/halib = $(DIR_CT_RUN)/saphascriptco.so
        service/halib_cluster_connector = /usr/bin/sap_suse_cluster_connector
    - unless:
      - cat {{ profile_file }} | grep '^service/halib'
    - require:
      - stop_sap_instance_{{ instance_name }}

add_sapuser_to_haclient_{{ instance_name }}:
  user.present:
    - name: {{ node.sid.lower() }}adm
    - remove_groups: False
    - groups:
      - haclient
    - require:
      - stop_sap_instance_{{ instance_name }}

{% if node.sap_instance.lower() == 'ascs' %}

adapt_sap_profile_ascs_{{ instance_name }}:
  file.replace:
    - name: {{ profile_file }}
    - pattern: '^Restart_Program_01 = local \$\(_EN\) pf=\$\(_PF\)'
    - repl: 'Start_Program_01 = local $(_EN) pf=$(_PF)'
    - require:
      - stop_sap_instance_{{ instance_name }}

set_keepalive_option_{{ instance_name }}:
  file.line:
    - name: {{ profile_file }}
    - mode: insert
    - location: end
    - content: enque/encni/set_so_keepalive = true
    # onlyif statements can be improved when salt version 3000 is used
    # https://docs.saltstack.com/en/latest/ref/states/requisites.html#onlyif
    - onlyif: cat /etc/salt/grains | grep "ensa_version_{{ node.sid.lower() }}_{{ instance }}:.*1"
    - require:
      - stop_sap_instance_{{ instance_name }}

{% elif node.sap_instance.lower() == 'ers' %}

adapt_sap_profile_ers_{{ instance_name }}:
  file.replace:
    - name: {{ profile_file }}
    - pattern: '^Restart_Program_00 = local \$\(_ER\) pf=\$\(_PFL\) NR=\$\(SCSID\)'
    - repl: 'Start_Program_00 = local $(_ER) pf=$(_PFL) NR=$(SCSID)'
    - require:
      - stop_sap_instance_{{ instance_name }}

remove_autostart_option_{{ instance_name }}:
  file.line:
    - name: {{ profile_file }}
    - match: ^Autostart = 1.*$
    - mode: delete
    - require:
      - stop_sap_instance_{{ instance_name }}

{% endif %}

start_sap_instance_service_{{ instance_name }}:
  module.run:
    - name: netweaver.execute_sapcontrol
    - function: 'StartService {{ node.sid.upper() }}'
    - sid: {{ node.sid.lower() }}
    - inst: {{ instance }}
    - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
    - test.sleep:
      - length: 15
    - require:
      - stop_sap_instance_{{ instance_name }}

start_sap_instance_{{ instance_name }}:
  module.run:
    - name: netweaver.execute_sapcontrol
    - function: 'Start'
    - sid: {{ node.sid.lower() }}
    - inst: {{ instance }}
    - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
    - test.sleep:
      - length: 15
    - require:
      - stop_sap_instance_{{ instance_name }}

{% endfor %}
EOF

cat <<EOF > /usr/share/salt-formulas/states/netweaver/install_ascs.sls
{%- from "netweaver/map.jinja" import netweaver with context -%}
{%- from "netweaver/extract_nw_archives.sls" import additional_dvd_folders with context -%}
{%- from "netweaver/extract_nw_archives.sls" import swpm_extract_dir with context -%}

{% set host = grains['host'] %}

{% for node in netweaver.nodes if node.host == host and node.sap_instance == 'ascs' %}

{% set instance = '{:0>2}'.format(node.instance) %}
{% set instance_name = node.sid~'_'~instance %}

{% set product_id = node.product_id|default(netweaver.product_id) %}
{% set product_id = 'NW_ABAP_ASCS:'~product_id if 'NW_ABAP_ASCS' not in product_id else product_id %}
{% set inifile = '/tmp/ascs.inifile'~instance_name~'.params' %}

create_ascs_inifile_{{ instance_name }}:
  file.managed:
    - source: salt://netweaver/templates/ascs.inifile.params.j2
    - name: {{ inifile }}
    - template: jinja
    - context: # set up context for template ascs.inifile.params.j2
        master_password: {{ netweaver.master_password }}
        sap_adm_password: {{ netweaver.sap_adm_password|default(netweaver.master_password) }}
        sid_adm_password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
        sid: {{ node.sid }}
        instance: {{ instance }}
        virtual_hostname: {{ node.virtual_host }}
        download_basket: {{ netweaver.sapexe_folder }}

{% if node.extra_parameters is defined %}
update_ascs_inifile_{{ instance_name }}:
  module.run:
    - name: netweaver.update_conf_file
    - conf_file: {{ inifile }}
    - {%- for key,value in node.extra_parameters.items() %}
      {{ key }}: "{{ value|string }}"
      {%- endfor %}
{% endif %}

netweaver_install_{{ instance_name }}:
  netweaver.installed:
    - name: {{ node.sid.lower() }}
    - inst: {{ instance }}
    - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
    - software_path: {{ netweaver.swpm_folder|default(swpm_extract_dir) }}
    - root_user: {{ node.root_user }}
    - root_password: {{ node.root_password }}
    - config_file: {{ inifile }}
    - virtual_host: {{ node.virtual_host }}
    - virtual_host_interface: {{ node.virtual_host_interface|default('eth0') }}
    - virtual_host_mask: {{ node.virtual_host_mask|default(24) }}
    - product_id: {{ product_id }}
    - cwd: {{ netweaver.installation_folder }}
    - additional_dvds: {{ additional_dvd_folders }}
    - require:
      - create_ascs_inifile_{{ instance_name }}

remove_ascs_inifile_{{ instance_name }}:
  file.absent:
    - name: {{ inifile }}
    - require:
      - create_ascs_inifile_{{ instance_name }}

{% endfor %}
EOF

cat <<EOF > /usr/share/salt-formulas/states/netweaver/install_ers.sls
{%- from "netweaver/map.jinja" import netweaver with context -%}
{%- from "netweaver/extract_nw_archives.sls" import additional_dvd_folders with context -%}
{%- from "netweaver/extract_nw_archives.sls" import swpm_extract_dir with context -%}

{% set host = grains['host'] %}

{% for node in netweaver.nodes if node.host == host and node.sap_instance == 'ers' %}

{% set instance = '{:0>2}'.format(node.instance) %}
{% set instance_name = node.sid~'_'~instance %}

{% set product_id = node.product_id|default(netweaver.product_id) %}
{% set product_id = 'NW_ERS:'~product_id if 'NW_ERS' not in product_id else product_id %}
{% set inifile = '/tmp/ers.inifile'~instance_name~'.params' %}

create_ers_inifile_{{ instance_name }}:
  file.managed:
    - source: salt://netweaver/templates/ers.inifile.params.j2
    - name: {{ inifile }}
    - template: jinja
    - context: # set up context for template ers.inifile.params.j2
        master_password: {{ netweaver.master_password }}
        sap_adm_password: {{ netweaver.sap_adm_password|default(netweaver.master_password) }}
        sid_adm_password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
        sid: {{ node.sid }}
        instance: {{ instance }}
        virtual_hostname: {{ node.virtual_host }}
        download_basket: {{ netweaver.sapexe_folder }}

{% if node.extra_parameters is defined %}
update_ers_inifile_{{ instance_name }}:
  module.run:
    - name: netweaver.update_conf_file
    - conf_file: {{ inifile }}
    - {%- for key,value in node.extra_parameters.items() %}
      {{ key }}: "{{ value|string }}"
      {%- endfor %}
{% endif %}

check_sapprofile_directory_exists_{{ instance_name }}:
  file.exists:
    - name: /sapmnt/{{ node.sid.upper() }}/profile
    - retry:
        attempts: 70
        interval: 30

netweaver_install_{{ instance_name }}:
  netweaver.installed:
    - name: {{ node.sid.lower() }}
    - inst: {{ instance }}
    - password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
    - software_path: {{ netweaver.swpm_folder|default(swpm_extract_dir) }}
    - root_user: {{ node.root_user }}
    - root_password: {{ node.root_password }}
    - config_file: {{ inifile }}
    - virtual_host: {{ node.virtual_host }}
    - virtual_host_interface: {{ node.virtual_host_interface|default('eth0') }}
    - virtual_host_mask: {{ node.virtual_host_mask|default(24) }}
    - product_id: {{ product_id }}
    - cwd: {{ netweaver.installation_folder }}
    - additional_dvds: {{ additional_dvd_folders }}
    - ascs_password: {{ netweaver.sid_adm_password|default(netweaver.master_password) }}
    - timeout: 1500
    - interval: {{ node.interval|default(30) }}
    - require:
      - create_ers_inifile_{{ instance_name }}
      - check_sapprofile_directory_exists_{{ instance_name }}

remove_ers_inifile_{{ instance_name }}:
  file.absent:
    - name: {{ inifile }}
    - require:
      - create_ers_inifile_{{ instance_name }}

{% endfor %}
EOF

# Generate Cluster config

cat <<EOF > /srv/pilllar/cib.config 
primitive rsc_socat_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} azure-lb \
  params port=620${sap_ascs_instance_id} \
  op monitor timeout=20s interval=10 depth=0

primitive rsc_socat_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} azure-lb \
  params port=621${sap_ers_instance_id} \
  op monitor timeout=20s interval=10 depth=0

primitive rsc_ip_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} IPaddr2 \
  params ip=${sap_ascs_vip_address} \
  op monitor interval=10s timeout=20s

primitive rsc_ip_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} IPaddr2 \
  params ip=${sap_ers_vip_address} \
  op monitor interval=10s timeout=20s

primitive rsc_exporter_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} systemd:prometheus-sap_host_exporter@${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} \
    op start interval=0 timeout=100 \
    op stop interval=0 timeout=100 \
    op monitor interval=10 \
    meta target-role=Started

primitive rsc_exporter_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} systemd:prometheus-sap_host_exporter@${sap_ers_instance_id}_ERS${sap_ascs_instance_sid} \
    op start interval=0 timeout=100 \
    op stop interval=0 timeout=100 \
    op monitor interval=10 \
    meta target-role=Started

primitive rsc_fs_${sap_ascs_instance_sid}_sapmnt Filesystem \
  params device="${sapmnt_inst_media}/sapmnt/" directory="${sapmnt_path}" fstype="nfs" \
  op start timeout=60s interval=0 \
  op stop timeout=60s interval=0 \
  op monitor interval=20s timeout=40s

primitive rsc_fs_${sap_ascs_instance_sid}_usr_sap Filesystem \
  params device="${sapmnt_inst_media}/usrsapsys/" directory="/usr/sap/" fstype="nfs" \
  op start timeout=60s interval=0 \
  op stop timeout=60s interval=0 \
  op monitor interval=20s timeout=40s

clone cln_${sap_ascs_instance_sid}_usr_sap rsc_fs_${sap_ascs_instance_sid}_usr_sap \
    meta is-managed="true" clone-node-max="1" interleave="true"

clone cln_${sap_ascs_instance_sid}_sapmnt rsc_fs_${sap_ascs_instance_sid}_sapmnt \
        meta is-managed="true" clone-node-max="1" interleave="true"

primitive rsc_sap_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} SAPInstance \
  operations $id=rsc_sap_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id}-operations \
  op monitor interval=120 timeout=60 on_fail=restart \
  params InstanceName=${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id}_${sap_ascs_vip_hostname} \
     START_PROFILE="${sapmnt_path}/${sap_ascs_instance_id}/profile/${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id}_${sap_ascs_vip_hostname}" \
     AUTOMATIC_RECOVER=false \
  meta resource-stickiness=5000 failure-timeout=60 migration-threshold=1 priority=10

group grp_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} \
  rsc_ip_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} \
  rsc_sap_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} \
  rsc_socat_${sap_ascs_instance_sid}_ASCS \
  rsc_exporter_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} \
  meta resource-stickiness=3000

primitive rsc_sap_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} SAPInstance \
  operations $id=rsc_sap_${sap_ers_instance_sid}_ERS${sap_ers_instance_id}-operations \
  op monitor interval=120 timeout=60 on_fail=restart \
  params InstanceName=${sap_ers_instance_sid}_ERS${sap_ers_instance_id}_${sap_ers_vip_hostname}} \
        START_PROFILE="${sapmnt_path}/${sap_ers_instance_sid}/profile/${sap_ers_instance_sid}_ERS${sap_ers_instance_id}_${sap_ers_vip_hostname}}" \
        AUTOMATIC_RECOVER=false IS_ERS=true meta priority=1000

group grp_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} \
  rsc_ip_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} \
  rsc_sap_${sap_ers_instance_sid}_ERS${sap_ers_instance_id}
  rsc_socat_${sap_ers_instance_sid}_ERS
  rsc_exporter_${sap_ers_instance_sid}_ERS${sap_ers_instance_id}

colocation col_sap_${sap_ers_instance_sid}_no_both -5000: grp_${sap_ers_instance_sid}_ERS${sap_ers_instance_id} grp_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id}

location loc_sap_${sap_ers_instance_sid}_failover_to_ers rsc_sap_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id} \
  rule 2000: runs_ers_${sap_ers_instance_sid} eq 1

order ord_sap_${sap_ers_instance_sid}_first_start_ascs Optional: rsc_sap_${sap_ascs_instance_sid}_ASCS{sap_ascs_instance_id}:start \
  rsc_sap_${sap_ers_instance_sid}_ERS${sap_ers_instance_id}:stop symmetrical=false

clone cln_${sap_ascs_instance_sid}_usr_sap rsc_fs_${sap_ascs_instance_sid}_usr_sap \
    meta is-managed="true" clone-node-max="1" interleave="true"

order ord_sap_fs_before_ascs 2000: cln_${sap_ascs_instance_sid}_usr_sap \
    rsc_fs_${sap_ascs_instance_sid}_usr_sap \
    rsc_fs_${sap_ascs_instance_sid}_sapmnt  \
    rsc_sap_${sap_ascs_instance_sid}_ASCS${sap_ascs_instance_id}

order ord_sap_fs_before_ascs 2000: cln_${sap_ascs_instance_sid}_usr_sap \
    rsc_fs_${sap_ascs_instance_sid}_usr_sap \
    rsc_fs_${sap_ascs_instance_sid}_sapmnt  \
    rsc_sap_${sap_ers_instance_sid}_ERS${sap_ers_instance_id}

EOF

# Remove authorized_keys file
rm -r /root/.ssh/authorized_keys 

# Set root password
echo "Changing root password ..."
pwd=$(salt-call --local shadow.gen_password "${admin_password}" --out txt | awk '{print $2}')
salt-call --local shadow.set_password root \'${pwd}\'

# Run salt for cluster deployment
echo "Setup cluster ..."
salt-call --local saltutil.clear_cache
salt-call --local saltutil.sync_all
salt-call --local -l debug state.apply cluster

# Configure stonith for Azure
#  pcmk_host_map="prod-cl1-0:prod-cl1-0-vm-name;prod-cl1-1:prod-cl1-1-vm-name" \
if [ ${vm_name} == ${vm_names[0]} ]; then
  crm configure property maintenance-mode=true
  crm configure primitive rsc_st_azure stonith:fence_azure_arm \
    params subscriptionId="${subscription_id}" resourceGroup="${resource_group}" \
    tenantId="${tenant_id}" login="${login_id}" passwd="${app_password}" \
    pcmk_monitor_retries=4 pcmk_action_limit=3 power_timeout=900 pcmk_reboot_timeout=900 \
    op monitor interval=3600 timeout=120
  #Create Pacemaker resources for the Azure agent
  crm configure primitive rsc_azure-events ocf:heartbeat:azure-events op monitor interval=10s
  crm configure clone cln_azure-events rsc_azure-events
  crm configure property stonith-enabled=true
  crm configure property maintenance-mode=false
fi

# Run salt for SAP deployment
# Command to add

