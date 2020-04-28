The following RHEL System Roles for SAP are provided  in rhel7.6 or later and rhel8

- sap-preconfigure
- sap-netweaver-preconfigure
- sap-hana-preconfigure


using the roles
- install package
    ```sh 
    yum install -y rhel-system-roles-sap  
    ```
- create ansible playbook `sap-hana.yml`
    ```yaml
    ---
    - hosts: localhost
      connection: local
      roles:
      - role: sap-preconfigure
      - role: sap-hana-preconfigure
    ```
- runing the playbook, This will configure the local hosts according to applicable SAP notes for SAP HANA.
    ```sh
    ansible-playbook sap-hana.yml
    ```
