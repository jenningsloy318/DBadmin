suppose the installation files are located  in /opt/HANA_DATABASES/SAP_HANA_DATABASE100_122_10/

1. install HANA DB in one command
    ```
    /opt/HANA_DATABASES/SAP_HANA_DATABASE100_122_10/hdblcm  --batch --action=install --components=server --sid=SP3 --number=04 -password=Toor1234 -sapadm_password=Toor1234 -system_user_password=Toor1234 --sapmnt=/hana/shared --datapath=/hana/data/SP3 --logpath=/hana/log/SP3
    ```
2. upgrade HANA in one command
    ```
    /opt/HANA_DATABASES/SAP_HANA_DATABASE100_122_10/hdblcm  --batch --action=update --components=server --sid=SP3  -password=Toor1234 -sapadm_password=Toor1234 -system_user_password=Toor1234 --sapmnt=/hana/shared  
    ```
3. uninstall HANA in one command
    ```
    /hana/shared/SP3/hdblcm/hdblcm --uninstall --batch
    ```