 sst-bench: script to test various data transfer methods used for SST in Percona XtraDB Cluster<br>

 Usage: sst-bench.sh options

 --mode        script role: donor - push data to joiner, joiner - awating data from donor<br>
 --sst-mode    sst-methods to test: xbackup, xbackup_enc, tar, rsync, rsync_improved<br>
 --ssl         use ssl for network connections (defaul:0 <0|1>)<br>
 --cipher      ssl cipher: DEFAULT, AES128, AES256, CHACHA20(for socat with openssl 1.1.0)<br>
 --xb-enc-key  file with encryption key for xbackup_enc mode<br>
 --aesni       AESNI enabled by default (defaul:1 <0|1>)<br>
