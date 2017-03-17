<pre>
sst-bench: script to measure time of various data transfer methods used for SST in Percona XtraDB Cluster<br>

 Usage: sst-bench.sh options

 --mode        script role: donor - push data to joiner, joiner - awating data from donor<br>
 --sst-mode    sst-methods to test: xbackup, xbackup_enc, tar, rsync, rsync_improved<br>
 --ssl         use ssl for network connections (defaul:0 <0|1>)<br>
 --cipher      ssl cipher: DEFAULT, AES128, AES256, CHACHA20(for socat with openssl 1.1.0)<br>
 --xb-enc-key  file with encryption key for xbackup_enc mode<br>
 --aesni       AESNI enabled by default (defaul:1 <0|1>)<br>

It's required to adjust environment variables in the begining of script before usage of the test.

Example:

Archiving datadir using tar and transfered it over SSL connection between donor and joiner hosts with AES128 cipher, support of AES-NI is disabled

#joiner_host> sst_bench.sh --mode=joiner --sst-mode=tar --cipher=AES128  --ssl=1 --aesni=0

Disabling AES_NI
/usr/bin/env OPENSSL_ia32cap="~0x200000200000000" socat -u openssl-listen:20202,reuseaddr,cipher=AES128,cert=/home/alexeys/sst_certs/server-cert.pem,key=/home/alexeys/sst_certs/server-key.pem,cafile=/home/alexeys/sst_certs/ca.pem,verify=0 stdio | tar -C /data/test -xf -


#donor_host>  sst_bench.sh --mode=donor --sst-mode=tar --cipher=AES128  --ssl=1 --aesni=0

Disabling AES_NI
time (cd  /data/test && /usr/bin/env OPENSSL_ia32cap="~0x200000200000000" tar -cO *  | socat -u stdio  openssl-connect:172.16.0.4:20202,cipher=AES128,cert=/home/alexeys/sst_certs/server-cert.pem,key=/home/alexeys/sst_certs/server-key.pem,cafile=/home/alexeys/sst_certs/ca.pem,verify=0 )

</pre>
