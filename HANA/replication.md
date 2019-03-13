Replication
---
1. add a secondary slave to a master in replication

For example, if remoteHostName is hana001, remoteInstanceNumber is 00, and SiteB is hana002, run the following command:
```shell
su - <sid>adm
hdbnsutil -sr_register --remoteHost=hana001 --remoteInstance=00 --replicationMode=sync --name=hana002
```
