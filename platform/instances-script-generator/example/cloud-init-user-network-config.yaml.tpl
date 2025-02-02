network:
  version: 2
  ethernets:
    ethnat:
      dhcp4: true
      dhcp6: false
      match:
        macaddress: ${vbox_instance_mac_address_nat_cloud_init}
      set-name: ethnat
      nameservers:
        addresses: [1.1.1.1]
    ethlab:
      dhcp4: true
      dhcp6: false
      match:
        macaddress: ${vbox_instance_mac_address_lab_cloud_init}
      set-name: ethlab
      nameservers:
        search:
          - '${project_domain}'
        addresses: [1.1.1.1]
