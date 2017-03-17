 sst-bench: script to test various data transfer methods used for SST in Percona XtraDB Cluster

 Usage: sst-bench.sh options

 --mode        script role: donor - push data to joiner, joiner - awating data from donor
 --sst-mode    sst-methods to test: xbackup, xbackup_enc, tar, rsync, rsync_improved
 --ssl         use ssl for network connections (defaul:0 <0|1>)
 --cipher      ssl cipher: DEFAULT, AES128, AES256, CHACHA20(for socat with openssl 1.1.0)
 --xb-enc-key  file with encryption key for xbackup_enc mode
 --aesni       AESNI enabled by default (defaul:1 <0|1>)
