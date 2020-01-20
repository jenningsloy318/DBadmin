1. network setup 

    |Function  |host1 | host2 |
    |---- |------|-------|
    |hostname|s1-rhel-prod01.inb.cnsgas.com|s1-rhel-prod02.inb.cnsgas.com|
    |data net| 10.36.50.110/25 (10.36.50.16)| 10.36.50.111/25 (10.36.50.16)|
    |sr net| 192.168.12.110|192.168.12.111|
    |habeat net| 192.168.11.110|192.168.11.111|

   OS: rhel 7.4.eus  
   HANA: 1.00.122.23.1548298510  
   SID: P01  
   InstanceNumber: 00 
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
    > - as `sbd` on RHEL don't support `softdog`, this may not be used in production environment, refer [Support Policies for RHEL High Availability Clusters - sbd and fence_sbd
](https://access.redhat.com/articles/2800691)

6. install HANA (HANA 1.00.122.23.1548298510) on both nodes with root user
    - install HANA
      ```
      /hana/SAP_HANA_DATABASE/hdblcm  --batch --action=install --components=server --sid=P01 --number=00 -password=Toor1234 -sapadm_password=Toor1234 -system_user_password=Toor1234 --sapmnt=/hana/shared --datapath=/hana/data/ --logpath=/hana/log/
      ```

    - create user for HA monitor via hana studio or hdbsql, which is called by HA components
      ```
      create user rhelhasync password Pass1234;
      grant CATALOG READ to rhelhasync;
      grant MONITOR ADMIN to rhelhasync;
      ALTER USER rhelhasync DISABLE PASSWORD LIFETIME;
      ```
      then create hdbstore with name `SAPHANA${SID}SR` under root user, this will be used for pacemaker `SAPHana` resource 
      ```
      /usr/sap/P01/HDB00/exe/hdbuserstore SET SAPHANAP01SR localhost:30015 rhelhasync Toor1234
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
    - with user p01adm, modify /hana/shared/P01/global/hdb/custom/config/global.ini, add following lines(this step is used to configure the hostname mapping for replication, here we can set dedicated IP address for repication)
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
  
  9. install HA packages on both nodes
      ```
      # yum install -y pacemaker corosync resource-agents-sap-hana pcs fence-agents-all
      ```
10. enable pcsd service on both nodes
    ```
    # systemctl start pcsd.service
    # systemctl enable pcsd.service
    ```
11. reset password for user `hacluster` on both nodes
    ```
    # passwd hacluster
    ```
12. authorize user `hacluster` to habeat ip and data ip address
    ```
    # pcs cluster auth  192.168.11.110 10.36.50.110 192.168.11.111 10.36.50.111
    Username: hacluster
    Password:
    192.168.11.111: Authorized
    192.168.11.110: Authorized
    10.36.50.111: Authorized
    10.36.50.110: Authorized
    ```
13. initialize cluster on node1, and set the cluster communication mode to unicast 
    ```
    # pcs cluster setup --name hacluster --start s1-rhel-prod01.inb.cnsgas.com,habeat01 s1-rhel-prod02.inb.cnsgas.com,habeat02  --enable
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
    s1-rhel-prod01.inb.cnsgas.com: Starting Cluster...
    s1-rhel-prod02.inb.cnsgas.com: Starting Cluster...

    Synchronizing pcsd certificates on nodes s1-rhel-prod01.inb.cnsgas.com, s1-rhel-prod02.inb.cnsgas.com...
    s1-rhel-prod02.inb.cnsgas.com: Success
    s1-rhel-prod01.inb.cnsgas.com: Success
    Restarting pcsd on the nodes in order to reload the certificates...
    s1-rhel-prod02.inb.cnsgas.com: Success
    s1-rhel-prod01.inb.cnsgas.com: Success
    ```

14. modify corosync quorum and then enable services on all nodes
    - open /etc/corosync/corosync.conf,  modify `quorum` block with following contents
      ```
          quorum {
            provider: corosync_votequorum
            expected_votes: 2

            #Enables two node cluster operations
            two_node:       1

      }
      ```

    - enable all services 
      ```
      # pcs cluster enable --all
      s1-rhel-prod01.inb.cnsgas.com: Starting Cluster...
      s1-rhel-prod02.inb.cnsgas.com: Starting Cluster...
      ```

    - restart cluster 
      ```
      # pcs cluster stop --all && pcs cluster start --all
      ```

    - check quorum setting
      ```
      # corosync-quorumtool
      Quorum information
      ------------------
      Date:             Mon Jan 20 10:02:12 2020
      Quorum provider:  corosync_votequorum
      Nodes:            2
      Node ID:          1
      Ring ID:          1/216
      Quorate:          Yes

      Votequorum information
      ----------------------
      Expected votes:   2
      Highest expected: 2
      Total votes:      2
      Quorum:           1
      Flags:            2Node Quorate WaitForAll

      Membership information
      ----------------------
          Nodeid      Votes Name
              1          1 s1-rhel-prod01.inb.cnsgas.com (local)
              2          1 s1-rhel-prod02.inb.cnsgas.com
      ```
    - check the heartbeat status.
      - node1 
        ```
            # corosync-cfgtool -s
            Printing ring status.
            Local node ID 1
            RING ID 0
                    id      = 192.168.11.110
                    status  = ring 0 active with no faults
            RING ID 1
                    id      = 10.36.50.110
                    status  = ring 1 active with no faults
        ```
          
      - node 2
        ```
        # corosync-cfgtool -s
        Printing ring status.
        Local node ID 1
        RING ID 0
                id      = 10.36.50.110
                status  = ring 0 active with no faults
        RING ID 1
                id      = 192.168.11.110
                status  = ring 1 active with no faults
        ```
15. check cluster status 
    
    ```
    # pcs status
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
   
16. configure cluster resources parameters
    ```
    # pcs property set no-quorum-policy="ignore"
    # pcs resource defaults default-resource-stickness=1000
    # pcs resource defaults default-migration-threshold=5000
    # pcs resource op defaults timeout=600s
    # pcs resource op record-pending=true
    # pcs property set have-watchdog=true
    # pcs property set placement-strategy="balanced"
    # pcs property set stonith-enabled=true
    # pcs property set stonith-action="reboot"
    #  pcs property set stonith-timeout=150s
    ```

17. configure the stonith resource instance on both nodes
  - install iscsi-initiator-utils 
    ```
    # yum install -y iscsi-initiator-utils sbd
    ```

    and get the initiatorname  from `/etc/iscsi/initiatorname.iscsi`
    - node 1: InitiatorName=iqn.1994-05.com.redhat:4cdda46957af
    - node 2: InitiatorName=iqn.1994-05.com.redhat:e9e0376d5e
  - discover the iscsi devices
    ```
    # iscsiadm -m discovery -t st -p 10.36.52.13:3260
    10.36.52.13:3260,1028 iqn.1992-08.com.netapp:sn.a42a2f4b7eb811e9ac2500a098f190b7:vs.3
    10.36.52.14:3260,1029 iqn.1992-08.com.netapp:sn.a42a2f4b7eb811e9ac2500a098f190b7:vs.3
    ```
  - login to the iscsi device
    ```
    # iscsiadm -m node -l
    Logging in to [iface: default, target: iqn.1992-08.com.netapp:sn.a42a2f4b7eb811e9ac2500a098f190b7:vs.3, portal: 10.36.52.13,3260] (multiple)
    Logging in to [iface: default, target: iqn.1992-08.com.netapp:sn.a42a2f4b7eb811e9ac2500a098f190b7:vs.3, portal: 10.36.52.14,3260] (multiple)
    Login to [iface: default, target: iqn.1992-08.com.netapp:sn.a42a2f4b7eb811e9ac2500a098f190b7:vs.3, portal: 10.36.52.13,3260] successful.
    Login to [iface: default, target: iqn.1992-08.com.netapp:sn.a42a2f4b7eb811e9ac2500a098f190b7:vs.3, portal: 10.36.52.14,3260] successful.
    ```

  - show iscsi devices
    ```
    # ls -l /dev/disk/by-id
    rwxrwx 1 root root  9 Jan 16 16:45 scsi-3600a09803831374a552b4e616c353075 -> ../../sdd
    lrwxrwxrwx 1 root root  9 Jan 16 16:45 wwn-0x600a09803831374a552b4e616c353075 -> ../../sdd
    ```
  - create sbd device with iscsi disk
    ```
    # sbd -d    /dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075 create 
    ```
  - dump sbd info
    ```
    # sbd -d /dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075 dump
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
  - allocate slots on both nodes for sbd device 
    ```
    # sbd -d /dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075 allocate s1-rhel-prod01.inb.cnsgas.com
    Trying to allocate slot for s1-rhel-prod01.inb.cnsgas.com on device /dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075.
    slot 0 is unused - trying to own
    Slot for s1-rhel-prod01.inb.cnsgas.com has been allocated on /dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075.

    # sbd -d /dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075 allocate s1-rhel-prod02.inb.cnsgas.com
    Trying to allocate slot for s1-rhel-prod02.inb.cnsgas.com on device /dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075.
    slot 1 is unused - trying to own
    Slot for s1-rhel-prod02.inb.cnsgas.com has been allocated on /dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075.
    ```
  - show sbd info 
    ```
    # sbd -d /dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075 list
    0       s1-rhel-prod01.inb.cnsgas.com   clear
    1       s1-rhel-prod02.inb.cnsgas.com   clear
    ```
  - config /etc/sysconfig/sbd, add following lines to the end
    ```
    SBD_DEVICE="/dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075"
    SBD_DELAY_START=no
    SBD_OPTS="-W"
    SBD_PACEMAKER=yes
    SBD_STARTMODE=always
    SBD_WATCHDOG=yes
    SBD_WATCHDOG_DEV=/dev/watchdog
    SBD_WATCHDOG_TIMEOUT=5
    ```
  - create stonith device 
    ```
    # pcs cluster stop --all
    # pcs stonith create stonith-sbd fence_sbd devices=/dev/disk/by-id/scsi-3600a09803831374a552b4e616c353075 pcmk_monitor_timeout=20s  op monitor interval=15 timeout=20
    # pcs stonith sbd  enable 
    # pcs cluster start --all
    ```
    show cluster status
    
    ```
    # pcs status 
    Cluster name: hacluster
    Stack: corosync
    Current DC: s1-rhel-prod02.inb.cnsgas.com (version 1.1.16-12.el7_4.8-94ff4df) - partition with quorum
    Last updated: Fri Jan 17 09:55:49 2020
    Last change: Fri Jan 17 09:54:40 2020 by hacluster via crmd on s1-rhel-prod02.inb.cnsgas.com

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
    >-  the type of the stonith is `fence_sbd`, and on Suse it is `external/sbd` both of them are same type of fence of `sbd poison-pill fencing`, refer 

    >- if running in VMWare vCenter environment, we can use fence_vmware_soap for fence, refer  https://access.redhat.com/solutions/917813
    > 
18. configure virtual IP address resource
    - create ip on master node
    ```
    # pcs resource create vip_SAPHana_P01_HDB00 IPaddr2  ip="10.36.50.112"  cidr_netmask=25 nic=ens192  op start timeout=20 interval=0  op stop timeout=20 interval=0 op monitor interval=10 timeout=20
    Assumed agent name 'ocf:heartbeat:IPaddr2' (deduced from 'IPaddr2')
    ```
19. Create SAPHanaTopology resource
    ```
    # pcs resource create SAPHanaTopology_P01_HDB00 SAPHanaTopology SID=P01 InstanceNumber=00 op start timeout=600 op stop timeout=300 op monitor interval=10 timeout=600 --clone meta is-managed=true clone-node-max=1 target-role="Started" interleave=true


    Assumed agent name 'ocf:heartbeat:SAPHanaTopology' (deduced from 'SAPHanaTopology')
    ```

20. create hana resource 
    ```
    # pcs resource create SAPHana_P01_HDB00 SAPHana  SID=P01  InstanceNumber=00  PREFER_SITE_TAKEOVER=true  DUPLICATE_PRIMARY_TIMEOUT=7200  AUTOMATED_REGISTER=true  op start timeout=3600  op stop timeout=3600  op promote timeout=3600  op demote timeout=3600  op monitor interval=60 role="Master" timeout=700  op monitor interval=61 role="Slave" timeout=700

    Assumed agent name 'ocf:heartbeat:SAPHana' (deduced from 'SAPHana')

    # pcs resource master SAPHana_P01_HDB00-master SAPHana_P01_HDB00  meta is-managed=true notify=true clone-max=2 clone-node-max=1  target-role="Started" interleave=true
    ```

21. configure constraint
- constraint - start SAPHanaTopology before SAPHana
  ```
  # pcs constraint order SAPHanaTopology_P01_HDB00-clone then SAPHana_P01_HDB00-master  symmetrical=false
  Adding SAPHanaTopology_P01_HDB00-clone SAPHana_P01_HDB00-master (kind: Mandatory) (Options: first-action=start then-action=start symmetrical=false)
  ```
- constraint - colocate vip_SAPHana_P01_HDB00 and SAPHana_P01_HDB00-master, make VIP and HANA instance co-exist.
```
pcs constraint colocation add vip_SAPHana_P01_HDB00 with master SAPHana_P01_HDB00-master 2000
```

- show constraint
  ```
  # pcs constraint
  Location Constraints:
  Ordering Constraints:
    start SAPHanaTopology_P01_HDB00-clone then start SAPHana_P01_HDB00-master (kind:Mandatory) (non-symmetrical)
  Colocation Constraints:
    vip_SAPHana_P01_HDB00 with SAPHana_P01_HDB00-master (score:2000) (rsc-role:Started) (with-rsc-role:Master)
  Ticket Constraints:
  ```
22. obtain the latest resource status.
    ```
    # pcs resource cleanup
    # pcs status
    Cluster name: hacluster
    Stack: corosync
    Current DC: s1-rhel-prod01.inb.cnsgas.com (version 1.1.16-12.el7_4.8-94ff4df) - partition with quorum
    Last updated: Fri Jan 17 14:23:00 2020
    Last change: Fri Jan 17 14:22:44 2020 by root via crm_attribute on s1-rhel-prod02.inb.cnsgas.com

    2 nodes configured
    8 resources configured

    Online: [ s1-rhel-prod01.inb.cnsgas.com s1-rhel-prod02.inb.cnsgas.com ]

    Full list of resources:

    stonith-sbd    (stonith:fence_sbd):    Started s1-rhel-prod01.inb.cnsgas.com
    vip_SAPHana_P01_HDB00  (ocf::heartbeat:IPaddr2):       Started s1-rhel-prod01.inb.cnsgas.com
    Clone Set: SAPHanaTopology_P01_HDB00-clone [SAPHanaTopology_P01_HDB00]
        Started: [ s1-rhel-prod01.inb.cnsgas.com s1-rhel-prod02.inb.cnsgas.com ]
    Master/Slave Set: SAPHana_P01_HDB00-master [SAPHana_P01_HDB00]
        Masters: [ s1-rhel-prod01.inb.cnsgas.com ]
        Slaves: [ s1-rhel-prod02.inb.cnsgas.com ]

    Daemon Status:
      corosync: active/enabled
      pacemaker: active/enabled
      pcsd: active/enabled
      sbd: active/enabled
    ```