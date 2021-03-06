**HANA SQL Statements**

1. user management
    
    1.1 create user
    ```
    ALTER USER USER1 PASSWORD Mpasswd1;
    ALTER USER USER1 DISABLE PASSWORD LIFETIME;
    ```
    1.2 unlock user:
    ```
    ALTER USER USER1 ACTIVATE USER NOW;
    ALTER USER USER1 DEACTIVATE USER NOW;
    ```
    
    if user is locked because of too many failed logon attempts, need to reset the attempts and then activate the user if neccessary
    ```
    ALTER USER USER1 RESET CONNECT ATTEMPTS;
    ```
    1.3 display user attributes  
    ```
    SELECT  * FROM SYS.USERS WHERE USER_NAME='ADMIN01';
    ```
    1.4 list all privileges and roles
    ```
    SELECT  * FROM SYS.PRIVILEGES  ORDER BY NAME;
    SELECT  * FROM SYS.ROLES ORDER by ROLE_NAME;
    ```
    1.5 list privileges/roles belong to a user: 
    ```
    SELECT * FROM "PUBLIC"."EFFECTIVE_PRIVILEGES" where USER_NAME = 'ADMIN01';
    SELECT * FROM "PUBLIC"."EFFECTIVE_ROLES" where USER_NAME = 'ADMIN01';
    ```

2. show current connections
    ```
    SELECT * FROM "SYS"."M_CONNECTIONS";
    ```

3. MDC sqls
    ```
    start tenant db: alter system start database dbname
    stop tenant db: alter system stop database dbname
    show all tenant db: select * from sys.m_databases
    show all services(including systemdb and tenant db): select * from sys_databases.m_services
    ```
4. change configuration

    Properties can be configured at different levels or layers depending on the configuration file.

    Layer |Description
    ------|-----------------
    System| The value configured for the system applies to the system as whole, including all hosts of multi-host systems and all tenant databases of multi-DB systems.
    Host | For some properties, it is possible to set host-specific values if the system has multiple hosts.If host-specific values are possible, you can expand the Hosts area of the Change Configuration Value dialog box, select the relevant host(s), and enter the host-specific value(s).It is possible to enter both a value for the system as a whole and for individual hosts. In this case, the system-specific value only applies to those hosts that do not have a hostspecific value.
    Database| For some properties, it is possible to set database-specific values if the system has tenant databases.If database-specific values are possible for a given property, they can be configured both in the system database and the tenant database.From the system database, you can configure database-specific values for all tenant databases in the system. From a tenant database, you can configure database-specific values only for that database.It is possible to enter a value for the system as a whole and individual databases. In this case, the system-specific value only applies to those databases that do not have a database-specific value.

    ```
    ALTER SYSTEM ALTER CONFIGURATION ('filename', layer) SET ('section1', 'key1') ='value1', ('section2', 'key2') = 'value2';
    ALTER SYSTEM ALTER CONFIGURATION('filename', 'layer'[, 'layername']) REMOVE('section1', 'key1'), ('section2', 'key2'), ('section3') with reconfigure;
    ```

    4.1 change configure to fix out of memory issue, set max_runtime_bytes to 2G.
    ```
    ALTER SYSTEM ALTER CONFIGURATION ('xsengine.ini', 'SYSTEM') SET('jsvm', 'max_runtime_bytes') ='2147483648' WITH RECONFIGURE;
    ```
    refer to https://launchpad.support.sap.com/#/notes/2041330/E

    4.2 change the password length
    ```
    ALTER SYSTEM ALTER CONFIGURATION ('indexserver.ini', 'SYSTEM') SET('password policy', 'minimal_password_length') ='7' WITH RECONFIGURE;
    ```
    4.3 Retrieve the current setting
    ```
    SELECT KEY, VALUE FROM M_INIFILE_CONTENTS WHERE FILE_NAME = 'indexserver.ini' AND SECTION = 'password policy' AND LAYER_NAME='SYSTEM' ;
    SELECT KEY, VALUE FROM M_INIFILE_CONTENTS WHERE FILE_NAME = 'indexserver.ini' AND SECTION = 'password policy' AND LAYER_NAME='DEFAULT' ;   

    SELECT FILE_NAME,SECTION,KEY, VALUE FROM M_INIFILE_CONTENTS WHERE LAYER_NAME='SYSTEM' ;

    ```
    4.4 configure S1 root_page and background image
    ```
    ALTER SYSTEM ALTER CONFIGURATION ('xsengine.ini', 'SYSTEM') SET('httpserver', 'login_screen_background_image') ='/sap/sports/custom/img/SportsOne_Portal_Login.jpg' WITH RECONFIGURE;
    ALTER SYSTEM ALTER CONFIGURATION ('xsengine.ini', 'SYSTEM') SET('httpserver', 'root_page') ='/sap/sports/fnd/ui/start/index.html' WITH RECONFIGURE;
    ```



5. export and import sql
    ```
    EXPORT <myschema>."*" AS BINARY INTO '/tmp/dump' WITH REPLACE THREADS 10;

    IMPORT ALL FROM '/tmp/dump' WITH REPLACE THREADS 10;
    ```

6. To grant/revoke privileges to a user 
    6.1 to grant/revoke **system privileges**
    ```
    grant RESOURCE ADMIN TO USER1;
    revoke RESOURCE ADMIN FROM USER1;
    ```

    6.2 to grant/revoke **object privileges**
    ```
    grant EXECUTE,DELETE,INSERT ON SCHEMA _SYS_REPO TO USER1;
    GRANT EXECUTE ON GRANT_SCHEMA_PRIVILEGE_ON_ACTIVATED_CONTENT TO USER1; 

    revoke EXECUTE,DELETE,INSERT ON SCHEMA _SYS_REPO FROM USER1
    ```

    6.3 to grant/revoke **system roles**
    ```
    grant CONTENT_ADMIN to USER1;
    revoke CONTENT_ADMIN FROM USER1
    ```

    6.4 to grant/revoke **repository roles**

    ```
    call _SYS_REPO.GRANT_ACTIVATED_ROLE('sap.hana.ide.roles::Developer', 'USER1');
    call _SYS_REPO.REVOKE_ACTIVATED_ROLE('sap.hana.ide.roles::Developer', 'USER1');
    ```
    > USER SHOUD HAVE `exec` on  OBJECT PRIVILEGE `_SYS.REPO` to excute this sql

    6.5 to grant/revoke **application privileges**



    ```
    CALL GRANT_APPLICATION_PRIVILEGE('"sap.sports.imp.appsvc.cockpit::access"','USER1');
    ```
    > USER SHOUD HAVE `execute` privilege on  OBJECT PRIVILEGE `GRANT_APPLICATION_PRIVILEGE(_SYS.REPO)` to excute this sql
7. backup data 

    7.1 login as <sid>adm, and create `user store` with hdbuserstore
    ```
    /usr/sap/<sid>/HDB<instancenumber>/exe/hdbuserstore SET <key_name> <server>:<port> <DB_user_name> <DB_user_password>
    ```

    7.3 login as  <sid>adm, make full backup
    
    ```
    /usr/sap/SP2/HDB03/exe/hdbsql -U BACKUPFORSP2 "BACKUP DATA ALL USING FILE('/backup/<sid>/data/backup_<sid>_$DATE')"
    ```

    7.4 incremental/Differential backup 

    ```
    hdbsql -U BACKUPFORSP2 "backup data INCREMENTAL using FILE('/backup/<sid>/data/backup_<sid>_$DATE')"
    hdbsql -U BACKUPFORSP2 "backup data DIFFERENTIAL using FILE('/backup/<sid>/data/backup_<sid>_$DATE')"

    ```
8. configure E-mail alerts
    we can use HANA studio to configure the alerts,but also we can set it with following sql
    ```
    insert into  "_SYS_STATISTICS"."STATISTICS_EMAILRECIPIENTS" values('-1','reciever@example.com','onchange');
    insert into  "_SYS_STATISTICS"."STATISTICS_PROPERTIES" values( 'internal.smtp.sender','sender@example.com');
    insert into  "_SYS_STATISTICS"."STATISTICS_PROPERTIES" values('internal.smtp.server','10.36.52.138');
    ```
**Appendix:**

1. Regex
```
%: Any string of zero or more characters.
_: Any single character.
[ ]: Any single character within the specified range (for example, [a-f]) or set (for example, [abcdef]).
[^]: Any single character not within the specified range (for example, [^a - f]) or set (for example, [^abcdef]).

LIKE 'Mc%' searches for all strings that begin with the letters Mc (McBadden).
LIKE '%inger' searches for all strings that end with the letters inger (Ringer, Stringer).
LIKE '%en%' searches for all strings that contain the letters en anywhere in the string (Bennet, Green, McBadden).
LIKE '_heryl' searches for all six-letter names ending with the letters heryl (Cheryl, Sheryl).
LIKE '[CK]ars[eo]n' searches for Carsen, Karsen, Carson, and Karson (Carson).
LIKE '[M-Z]inger' searches for all names ending with the letters inger that begin with any single letter from M through Z (Ringer).
LIKE 'M[^c]%' searches for all names beginning with the letter M that do not have the letter c as the second letter (MacFeather).
```