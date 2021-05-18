netweaver:
  # optional: Install required packages to install SAP Netweaver (true by default)
  # If set to false, these packages must be installed before the formula execution manually
  # install_packages: true

  virtual_addresses:
    10.0.1.101: sap-ascs-1
    10.0.1.102: sap-ascs-2
    10.0.1.100: hana
    10.0.1.200: sap-ascs-vip
    10.0.1.201: sap-ers-vip

 # Create sidadm and sapsys user/group.
  # If this entry exists the user and group will be created before the installation, not otherwise
  sidadm_user:
    uid: 1003
    gid: 1002
  # sid_adm_password is optional, master password will be used as default, if value is not defined
  sid_adm_password: Passw0rd123
  # sap_adm_password is optional, master password will be used as default, if value is not defined
  sap_adm_password: Passw0rd123
  # Master password is used for all the SAP users that are created
  master_password: Passw0rd123

  # Local path where sapmnt data is stored. This is a local path. This folder can be mounted in a NFS share
  # using sapmnt_inst_media
  # /sapmnt by default
  sapmnt_path: /sapmnt
  # Define NFS share where sapmnt and SYS folder will be mounted. This NFS share must already have
  # the sapmnt and usrsapsys folders
  # If it is not used or empty string is set, the sapmnt and SYS folder are created locally
  sapmnt_inst_media: 10.0.1.6:/var/sapmnt
  # Clean /sapmnt/{sid} and /usr/sap/{sid}/SYS content. It will only work if ASCS node is defined.
  # True by default. It only works if a NFS share is defined in sapmnt_inst_media
  clean_nfs: True
  # Used to connect to the nfs share
  # nfs_version: nfs4
  # nfs_options: defaults
  # Use the next options for AWS for example
  # nfs_options: rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2

  # Specify the path to already extracted SWPM installer folder
  swpm_folder: /mnt/sapmedia/swpm_/
  # Or specify the path to the sapcar executable & SWPM installer sar archive, to extract the installer
  # The sar archive will be extracted to a subfolder SWPM, under nw_extract_dir (optional, by default /sapmedia_extract/NW/SWPM)
  # Make sure to use the latest/compatible version of sapcar executable, and that it has correct execute permissions
  # sapcar_exe_file: your_sapcar_exe_file_absolute_path
  # swpm_sar_file: your_swpm_sar_file_absolute_path
  # nw_extract_dir: location_to_extract_nw_media_absolute_path
  sapexe_folder: 	/mnt/sapmedia/kernel_novo/part1/
  # Folder where the installation files are stored. /tmp/swpm_unattended by default. Set None to use
  # SAP default folders (it will only work with ASCS and ERS).
  # This folder content will be removed before the installation so be extra careful!
  installation_folder: /tmp/swpm_unattended
  # DB/PAS/AAS instances require additional DVD folders like NW Export or HDB Client folder
  # Provide the absolute path to software folder or archives with additional SAP software needed to install netweaver
  additional_dvds:
    - /mnt/sapmedia/misc/


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
    host: 10.0.1.100
    sid: PRD
    instance: 00
    password: Passw0rd123

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
    - host: sap-ascs-1
      virtual_host: sap-ascs-vip
      # virtual_host_interface: eth1 # eth0 by default
      # virtual_host_mask: 32 # 24 by default
      sid: HA1
      instance: 01
      root_user: root
      root_password: Passw0rd123
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

    - host: sap-ascs-2
      virtual_host: sap-ers-vip
      sid: HA1
      instance: 10
      saptune_solution: 'MAXDB'
      root_user: root
      root_password: Passw0rd123
      # Set the shared disk used in HA environments. Skip this parameter in non HA environments
      # shared_disk_dev: /dev/sbd
      # If a nfs share is used to manage the HA mounting point, like in the cloud
      #shared_disk_dev: your_nfs_share_SID_folder/ERS
      sap_instance: ers
