 1. create csr with dmo.pse, with req demo.req, which has several DNS/IPaddress altername 
sapgenpse gen_pse -x ""   -p dmo2.pse -r dmo2.req -a sha256WithRsaEncryption -s 2048    -k GN-dNSName:yhbmhdbdemo01.snfc.org -k -k GN-dNSName:sports-staging.snfc.com  -k -k GN-dNSName:sportsone-demo.snfc.org  -k GN-iPAddress:10.36.50.141 "CN=yhbmhdbdemo01"

2. convert  dmo.pem(signed by ca.pem) to pkcs7(p7b) formatm 
```
openssl crl2pkcs7 -nocrl -certfile dmo.pem -out dmo.p7b -certfile ca.pem

```