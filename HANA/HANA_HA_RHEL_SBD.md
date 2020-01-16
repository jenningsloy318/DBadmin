1. network setup 

    |Function  |host1 | host2 |
    |---- |------|-------|
    |hostname|s1-rhel-prod01.inb.cnsgas.com|s1-rhel-prod02.inb.cnsgas.com|
    |data net| 10.36.50.110/25 (10.36.50.16)| 10.36.50.111/25 (10.36.50.16)|
    |sr net| 192.168.12.110|192.168.12.111|
    |habeat net| 192.168.11.110|192.168.11.111|

   OS: rhel 7.4   
   HANA: 1.00.122.23.1548298510
2. modify /etc/hosts on both nodes

    ```sh
    cat /etc/hosts
    192.168.11.110   habeat01
    192.168.12.110   srnode01
    10.36.50.110    s1-rhel-prod01.inb.cnsgas.com  s1-rhel-prod01

    192.168.11.111   habeat02
    192.168.12.111   srnode02
    10.36.50.111    s1-rhel-prod02.inb.cnsgas.com  s1-rhel-prod02
    ```
3. config ssh key auth for root 

4. config repo rhel74-eus.repo
    ```
    [rhel_7_server_rpms_eus]
    name=rhel_7_server
    baseurl=http://10.36.52.189/rhel74_eus/rhel-x86_64-server-7.4.eus/
    enabled=1
    gpgcheck=1
    gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release


    [rhel_7_server_optional_rpms_eus]
    name=rhel_7_server_optional
    baseurl=http://10.36.52.189/rhel74_eus/rhel-x86_64-server-optional-7.4.eus/
    enabled=1
    gpgcheck=1
    gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release


    [rhel_7_server_sap_hana_rpms_eus]
    name=rhel_7_server_sap
    baseurl=http://10.36.52.189/rhel74_eus/rhel-x86_64-server-sap-hana-7.4.eus/
    enabled=1
    gpgcheck=1
    gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release


    [rhel_7_server_ha_rpms_eus]
    name=rhel_7_server_sap
    baseurl=http://10.36.52.189/rhel74_eus/rhel-x86_64-server-ha-7.4.eus/
    enabled=1
    gpgcheck=1
    gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release


    [rhel_7_server_supplementary_rpms_eus]
    name=rhel_7_server_sap
    baseurl=http://10.36.52.189/rhel74_eus/rhel-x86_64-server-supplementary-7.4.eus/
    enabled=1
    gpgcheck=1
    gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
    ```
5. enable softdog  with root user
    ```
    modprobe softdog
    ```
 
    make it loaded at boot
    
    ```
    cat /etc/modules-load.d/softdog.conf
    softdog
    ```
    check wathdog 
    ```
    ls -l /dev/watchdog
    crw------- 1 root root 10, 130 Jan 14 16:55 /dev/watchdog
    ```

6. install HANA (HANA 1.00.122.23.1548298510) on both nodes with root user
    ```
    /hana/SAP_HANA_DATABASE/hdblcm  --batch --action=install --components=server --sid=P01 --number=00 -password=Toor1234 -sapadm_password=Toor1234 -system_user_password=Toor1234 --sapmnt=/hana/shared --datapath=/hana/data/ --logpath=/hana/log/
    ```

7. enable sapinit at boot with root user
    ```
    chkconfig sapinit on
    ```

    make sure  hana autoboot is disabled, set `Autostart` to `0`
    ```
    su - p01adm
    grep -i  Autostart /usr/sap/P01/SYS/profile/*
    /usr/sap/P01/SYS/profile/P01_HDB00_s1-rhel-prod01.inb.cnsgas.com:Autostart = 0
    ```

8. configure system replication
    - configure ssh key auth for <sid>adm user, make sure <sid>adm can ssh mutually with sr net
    - ensure hana log mode set to `normal`
    - backup hana db on node1 
    - with user p01adm, modify /hana/shared/P01/global/hdb/custom/config/global.ini, add following lines
      ```
      [system_replication_communication]
      listeninterface = .global

      [system_replication_hostname_resolution]
      192.168.12.111 = s1-rhel-prod02.inb.cnsgas.com
      ```
    
    or

      ```
      [system_replication_communication]
      listeninterface = .internal

      [system_replication_hostname_resolution]
      192.168.12.111 = s1-rhel-prod02.inb.cnsgas.com
      192.168.12.110 = s1-rhel-prod01.inb.cnsgas.com
      ```

    > - if `listeninterface` set to `global`, then `system_replication_hostname_resolution` should only mapping remote site ; if `listeninterface` set to `internal`, `system_replication_hostname_resolution` must mapping both local and remote site
    > - the hostname mapping should use the default hostname, e.g `s1-rhel-prod01.inb.cnsgas.com` but not `srnode1`, since HANA running with the default hostname, this the difference set with `/etc/hosts`

    - enable system replication on node1 with p01adm user
      ```
      hdbnsutil -sr_enable --name=siteA
      ```

    - register standby with p01adm user
      ```
      HDB stop
      hdbnsutil -sr_register --remoteHost=s1-rhel-prod01.inb.cnsgas.com --remoteInstance=00 --replicationMode=sync --name=siteB --operationMode=logreplay

      adding site ...
      nameserver s1-rhel-prod02.inb.cnsgas.com:30001 not responding.
      collecting information ...
      registered at 192.168.12.110 (s1-rhel-prod01.inb.cnsgas.com)
      updating local ini files ...
      done.
      ```
    - start HANA on standby with p01adm
      ```
      HDB start
      ```
    - check repication status with p01adm user
      ```
      $ cdpy 
      $ python systemReplicationStatus.py
    | Host                          | Port  | Service Name | Volume ID | Site ID | Site Name | Secondary Host   | Secondary Port  | Secondary  Site ID| Secondary Site Name  | Secondary   Site Name  | Replication Mode | Replication Status | Replication  Details  |
    | ----------------------------- | ----- | ------------ | --------- | ------- | --------- | ----------------------------- | --------- | --------- | --------- | ------------- | ----------- | ----------- | -------------- |
    | s1-rhel-prod01.inb.cnsgas.com | 30007 | xsengine     |         3 |       1 | siteA     | s1-rhel-prod02.inb.cnsgas.com |     30007 |         2 | siteB     | YES           | SYNC        | ACTIVE      |                |
    | s1-rhel-prod01.inb.cnsgas.com | 30001 | nameserver   |         1 |       1 | siteA     | s1-rhel-prod02.inb.cnsgas.com |     30001 |         2 | siteB     | YES           | SYNC        | ACTIVE      |                |
    | s1-rhel-prod01.inb.cnsgas.com | 30003 | indexserver  |         2 |       1 | siteA     | s1-rhel-prod02.inb.cnsgas.com |     30003 |         2 | siteB     | YES           | SYNC        | ACTIVE      |                |

    status system replication site "2": ACTIVE
    overall system replication status: ACTIVE

    Local System Replication State
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    mode: PRIMARY
    site id: 1
    site name: siteA
    ```