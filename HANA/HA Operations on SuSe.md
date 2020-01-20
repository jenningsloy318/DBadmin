1. enter maintenance mode
```
crm configure property maintenance-mode=true
```
2. exit maintenance mode
```
crm configure property maintenance-mode=false
```

3. check the replication status on master node

```
$ cdpy   
$ python systemReplicationStatus.py
```
output: 


| Host| Port | Service Name | Volume ID | Site ID | Site Name | Secondary Host| Secondary | Secondary Port| Secondary | Secondary   Site Name  | Replication Active Status| Replication Status| Replication  Status Details  |
| ----------------------------- | ----- | ------------ | --------- | ------- | --------- | ----------------------------- | --------- | --------- | --------- | ------------- | ----------- | ----------- | -------------- |
| dc1-vm-hothot-s1-prod01-inst1 | 30007 | xsengine     |         2 |       1 | SiteA     | dc1-vm-hothot-s1-prod01-inst2 |     30007 |         2 | SiteB     | YES           | ASYNC       | ACTIVE      |                |
| dc1-vm-hothot-s1-prod01-inst1 | 30001 | nameserver   |         1 |       1 | SiteA     | dc1-vm-hothot-s1-prod01-inst2 |     30001 |         2 | SiteB     | YES           | ASYNC       | ACTIVE      |                |
| dc1-vm-hothot-s1-prod01-inst1 | 30003 | indexserver  |         3 |       1 | SiteA     | dc1-vm-hothot-s1-prod01-inst2 |     30003 |         2 | SiteB     | YES           | ASYNC       | ACTIVE      |                |

status system replication site "2": ACTIVE     
overall system replication status: ACTIVE

Local System Replication State


mode: PRIMARY
site id: 1
site name: SiteA
