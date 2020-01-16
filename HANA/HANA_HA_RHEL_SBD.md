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
      ```
      
      | Host                          | Port  | Service Name | Volume ID | Site ID | Site Name | Secondary Host   | Secondary Port  | Secondary  Site ID| Secondary Site Name  | Secondary   Site Name  | Replication Mode | Replication Status | Replication  Details  |
      | ----------------------------- | ----- | ------------ | --------- | ------- | --------- | ----------------------------- | --------- | --------- | --------- | ------------- | ----------- | ----------- | -------------- |
      | s1-rhel-prod01.inb.cnsgas.com | 30007 | xsengine     |         3 |       1 | siteA     | s1-rhel-prod02.inb.cnsgas.com |     30007 |         2 | siteB     | YES           | SYNC        | ACTIVE      |                |
      | s1-rhel-prod01.inb.cnsgas.com | 30001 | nameserver   |         1 |       1 | siteA     | s1-rhel-prod02.inb.cnsgas.com |     30001 |         2 | siteB     | YES           | SYNC        | ACTIVE      |                |
      | s1-rhel-prod01.inb.cnsgas.com | 30003 | indexserver  |         2 |       1 | siteA     | s1-rhel-prod02.inb.cnsgas.com |     30003 |         2 | siteB     | YES           | SYNC        | ACTIVE      |                |
      ```
      status system replication site "2": ACTIVE
      overall system replication status: ACTIVE

      Local System Replication State
      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

      mode: PRIMARY
      site id: 1
      site name: siteA
      ```
  
  9. install HA packages
      ```
      yum install -y pacemaker corosync resource-agents-sap-hana pcs fence-agents-all
      ```
10. enable pcsd service on both nodes
    ```
    systemctl start pcsd.service
    systemctl enable pcsd.service
    ```
11. reset password for user `hacluster` on both nodes
    ```
    passwd hacluster
    ```
12. authorize user `hacluster` to habeat ip and data ip address
    ```
    pcs cluster auth  192.168.11.110 10.36.50.110 192.168.11.111 10.36.50.111
    Username: hacluster
    Password:
    192.168.11.111: Authorized
    192.168.11.110: Authorized
    10.36.50.111: Authorized
    10.36.50.110: Authorized
    ```
13. initialize cluster on node1, and set the cluster communication mode to unicast 
    ```
 pcs cluster setup --name hacluster --start 192.168.11.110,10.36.50.110 192.168.11.111,10.36.50.111 --transport udpu 
Destroying cluster on nodes: 192.168.11.110, 192.168.11.111...
192.168.11.111: Stopping Cluster (pacemaker)...
192.168.11.110: Stopping Cluster (pacemaker)...
192.168.11.111: Successfully destroyed cluster
192.168.11.110: Successfully destroyed cluster

Sending 'pacemaker_remote authkey' to '192.168.11.110', '192.168.11.111'
192.168.11.110: successful distribution of the file 'pacemaker_remote authkey'
192.168.11.111: successful distribution of the file 'pacemaker_remote authkey'
Sending cluster config files to the nodes...
192.168.11.110: Succeeded
192.168.11.111: Succeeded

Starting cluster on nodes: 192.168.11.110, 192.168.11.111...
192.168.11.110: Starting Cluster...
192.168.11.111: Starting Cluster...

Synchronizing pcsd certificates on nodes 192.168.11.110, 192.168.11.111...
192.168.11.111: Success
192.168.11.110: Success
Restarting pcsd on the nodes in order to reload the certificates...
192.168.11.111: Success
192.168.11.110: Success
```

```
#  pcs cluster setup --name hacluster --start s1-rhel-prod01.inb.cnsgas.com,s1-rhel-prod01.inb.cnsgas.com s1-rhel-prod02.inb.cnsgas.com,habeat02 --transport udpu
pcs cluster setup --name hacluster --start s1-rhel-prod01.inb.cnsgas.com,s1-rhel-prod01.inb.cnsgas.com s1-rhel-prod02.inb.cnsgas.com,habeat02 --transport udpu --force
Destroying cluster on nodes: s1-rhel-prod01.inb.cnsgas.com, s1-rhel-prod02.inb.cnsgas.com...
s1-rhel-prod01.inb.cnsgas.com: Stopping Cluster (pacemaker)...
s1-rhel-prod02.inb.cnsgas.com: Stopping Cluster (pacemaker)...
s1-rhel-prod01.inb.cnsgas.com: Successfully destroyed cluster
s1-rhel-prod02.inb.cnsgas.com: Successfully destroyed cluster

Sending 'pacemaker_remote authkey' to 's1-rhel-prod01.inb.cnsgas.com', 's1-rhel-prod02.inb.cnsgas.com'
s1-rhel-prod01.inb.cnsgas.com: successful distribution of the file 'pacemaker_remote authkey'
s1-rhel-prod02.inb.cnsgas.com: successful distribution of the file 'pacemaker_remote authkey'
Sending cluster config files to the nodes...
s1-rhel-prod01.inb.cnsgas.com: Succeeded
s1-rhel-prod02.inb.cnsgas.com: Succeeded

Starting cluster on nodes: s1-rhel-prod01.inb.cnsgas.com, s1-rhel-prod02.inb.cnsgas.com...
s1-rhel-prod02.inb.cnsgas.com: Starting Cluster...
s1-rhel-prod01.inb.cnsgas.com: Starting Cluster...

Synchronizing pcsd certificates on nodes s1-rhel-prod01.inb.cnsgas.com, s1-rhel-prod02.inb.cnsgas.com...
s1-rhel-prod02.inb.cnsgas.com: Success
s1-rhel-prod01.inb.cnsgas.com: Success
Restarting pcsd on the nodes in order to reload the certificates...
s1-rhel-prod02.inb.cnsgas.com: Success
s1-rhel-prod01.inb.cnsgas.com: Success
```

14. enable services on all nodes
```
pcs cluster enable --all
192.168.11.110: Cluster Enabled
192.168.11.111: Cluster Enabled
```
or
```
s1-rhel-prod01.inb.cnsgas.com: Starting Cluster...
s1-rhel-prod02.inb.cnsgas.com: Starting Cluster...
```
15. check cluster status 
    ```
    pcs status
    Cluster name: hacluster
    WARNING: no stonith devices and stonith-enabled is not false
    WARNING: corosync and pacemaker node names do not match (IPs used in setup?)
    Stack: corosync
    Current DC: s1-rhel-prod02.inb.cnsgas.com (version 1.1.16-12.el7_4.8-94ff4df) - partition with quorum
    Last updated: Thu Jan 16 15:56:26 2020
    Last change: Thu Jan 16 15:54:14 2020 by hacluster via crmd on s1-rhel-prod02.inb.cnsgas.com

    2 nodes configured
    0 resources configured

    Online: [ s1-rhel-prod01.inb.cnsgas.com s1-rhel-prod02.inb.cnsgas.com ]

    No resources


    Daemon Status:
      corosync: active/enabled
      pacemaker: active/enabled
      pcsd: active/enabled
    ```
    or 
    ```
    Cluster name: hacluster
    WARNING: no stonith devices and stonith-enabled is not false
    Stack: corosync
    Current DC: s1-rhel-prod02.inb.cnsgas.com (version 1.1.16-12.el7_4.8-94ff4df) - partition with quorum
    Last updated: Thu Jan 16 18:44:45 2020
    Last change: Thu Jan 16 18:42:51 2020 by hacluster via crmd on s1-rhel-prod02.inb.cnsgas.com

    2 nodes configured
    0 resources configured

    Online: [ s1-rhel-prod01.inb.cnsgas.com s1-rhel-prod02.inb.cnsgas.com ]

    No resources


    Daemon Status:
      corosync: active/enabled
      pacemaker: active/enabled
      pcsd: active/enabled
  ```
16. On the node 1, run the corosync-cfgtool -s command to check the heartbeat status.
    ```
    corosync-cfgtool -s
    Printing ring status.
    Local node ID 1
    RING ID 0
            id      = 192.168.11.110
            status  = ring 0 active with no faults
    RING ID 1
            id      = 10.36.50.110
            status  = ring 1 active with no faults
    ```
    or
    ```
    Printing ring status.
    Local node ID 1
    RING ID 0
            id      = 10.36.50.110
            status  = ring 0 active with no faults
    RING ID 1
            id      = 10.36.50.110
            status  = Marking ringid 1 interface 10.36.50.110 FAULTY
    ```
17. configure cluster resources parameters on node1
```
 pcs property set no-quorum-policy="stop"
 pcs resource defaults default-resource-stickness=1000
 pcs resource defaults default-migration-threshold=5000
 pcs resource op defaults timeout=600s
```

18. configure the stonith resource instance on both nodes
  - install iscsi-initiator-utils 
    ```
    yum install -y iscsi-initiator-utils sbd
    ```

    and get the initiatorname  from `/etc/iscsi/initiatorname.iscsi`
    - node 1: InitiatorName=iqn.1994-05.com.redhat:4cdda46957af
    - node 2: InitiatorName=iqn.1994-05.com.redhat:e9e0376d5e
  - discover the iscsi devices
    ```
    iscsiadm -m discovery -t st -p 10.36.52.13:3260
    10.36.52.13:3260,1028 iqn.1992-08.com.netapp:sn.a42a2f4b7eb811e9ac2500a098f190b7:vs.3
    10.36.52.14:3260,1029 iqn.1992-08.com.netapp:sn.a42a2f4b7eb811e9ac2500a098f190b7:vs.3
    ```
  - login to the iscsi device
    ```
    iscsiadm -m node -l
    Logging in to [iface: default, target: iqn.1992-08.com.netapp:sn.a42a2f4b7eb811e9ac2500a098f190b7:vs.3, portal: 10.36.52.13,3260] (multiple)
    Logging in to [iface: default, target: iqn.1992-08.com.netapp:sn.a42a2f4b7eb811e9ac2500a098f190b7:vs.3, portal: 10.36.52.14,3260] (multiple)
    Login to [iface: default, target: iqn.1992-08.com.netapp:sn.a42a2f4b7eb811e9ac2500a098f190b7:vs.3, portal: 10.36.52.13,3260] successful.
    Login to [iface: default, target: iqn.1992-08.com.netapp:sn.a42a2f4b7eb811e9ac2500a098f190b7:vs.3, portal: 10.36.52.14,3260] successful.
    ```

  - show iscsi devices
    ```
    ls -l /dev/disk/by-id
    rwxrwx 1 root root  9 Jan 16 16:45 scsi-3600a09803831374a552b4e616c353075 -> ../../sdd
    lrwxrwxrwx 1 root root  9 Jan 16 16:45 wwn-0x600a09803831374a552b4e616c353075 -> ../../sdd
    ```
  - create sbd device with iscsi disk
    ```
    sbd -d    /dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075 create 
    ```
  - dump sbd info
    ```
    sbd -d /dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075 dump
    ==Dumping header on disk /dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075
    Header version     : 2.1
    UUID               : efcc9fe8-987b-4b9b-8133-5a4fe630681b
    Number of slots    : 255
    Sector size        : 512
    Timeout (watchdog) : 5
    Timeout (allocate) : 2
    Timeout (loop)     : 1
    Timeout (msgwait)  : 10
    ==Header on disk /dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075 is dumped
    ```
  - config /etc/sysconfig/sbd, add following lines to the end
    ```
    SBD_DEVICE="/dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075"
    SBD_WATCHDOG="yes"
    SBD_PACEMAKER="yes"
    SBD_STARTMODE="clean"
    ```
  - create stonith device 
    ```
    # pcs stonith create stonith-sbd fence_sbd devices=/dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075 pcmk_monitor_timeout=20s  op monitor interval=15s
    # pcs stonith sbd  enable 
    # pcs cluster stop  --all &&  pcs cluster start --all
    
    # pcs status 
    Cluster name: hacluster
    WARNING: corosync and pacemaker node names do not match (IPs used in setup?)
    Stack: corosync
    Current DC: s1-rhel-prod01.inb.cnsgas.com (version 1.1.16-12.el7_4.8-94ff4df) - partition with quorum
    Last updated: Thu Jan 16 18:18:28 2020
    Last change: Thu Jan 16 18:17:59 2020 by hacluster via cibadmin on s1-rhel-prod01.inb.cnsgas.com

    2 nodes configured
    1 resource configured

    Online: [ s1-rhel-prod01.inb.cnsgas.com s1-rhel-prod02.inb.cnsgas.com ]

    Full list of resources:

    stonith-sbd    (stonith:fence_sbd):    Started s1-rhel-prod01.inb.cnsgas.com

    Daemon Status:
      corosync: active/enabled
      pacemaker: active/enabled
      pcsd: active/enabled
      sbd: active/enabled
    ```
    or 
    ```
    Cluster name: hacluster
    Stack: corosync
    Current DC: s1-rhel-prod02.inb.cnsgas.com (version 1.1.16-12.el7_4.8-94ff4df) - partition with quorum
    Last updated: Thu Jan 16 18:47:35 2020
    Last change: Thu Jan 16 18:46:04 2020 by root via cibadmin on s1-rhel-prod01.inb.cnsgas.com

    2 nodes configured
    1 resource configured

    Online: [ s1-rhel-prod01.inb.cnsgas.com s1-rhel-prod02.inb.cnsgas.com ]

    Full list of resources:

    stonith-sbd    (stonith:fence_sbd):    Started s1-rhel-prod01.inb.cnsgas.com

    Daemon Status:
      corosync: active/enabled
      pacemaker: active/enabled
      pcsd: active/enabled
    ```
