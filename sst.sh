#!/bin/bash


joiner_host="172.16.0.4"
joiner_port="20202"

#######
# SOCAT
#######
# socat network buffer size 
# default=8192 wo/SSL(8M)=8589934592  w/SSL = 1M = 1073741824
socat_netbuf=8589934592

# socat SSL
ssl_ca=~/certs/ca.pem
ssl_cert=~/certs/server-cert.pem
ssl_key=~/certs/server-key.pem

cipher_list_aes128="ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:DHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-SHA256"
cipher_list_aes256="ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:DHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA256"
cipher_list_chacha20="ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-CHACHA20-POLY1305:DHE-RSA-CHACHA20-POLY1305:PSK-CHACHA20-POLY1305:ECDHE-PSK-CHACHA20-POLY1305:DHE-PSK-CHACHA20-POLY1305:RSA-PSK-CHACHA20-POLY1305"

#How to generate key for xtrabackup enc
#key_file="~/certs/xtrabackup.key"
#pass="secret123"
#algo=<aes-128-cbc|aes-256-cbc>
#key=$(openssl enc -<algo> -k <pass> -P -md sha1 | grep iv | cut -d'=' -f2); echo -n "$key" > $key_file

############
# XTRABACKUP
############
xb_threads=4
donor_datadir=/data/sam/sbtest100t4M.pxc
joiner_datadir=/data/sam/2

# xtrabackup ecryption
xb_enc_threads=4
# aes128|aes256
xb_enc_algo=aes128
xb_enc_key=xtrabackup_aes128.key
xb_enc_chunk=1M

######
# BBCP
######
bbcp_netbuf=8M
bbcp_threads=8

donor_cmd_xtrabackup() 
{
  cmd="xtrabackup --backup --datadir=$donor_datadir --stream=xbstream --parallel=$xb_threads"
}

donor_cmd_xtrabackup_enc()
{
  cmd="xtrabackup --backup --datadir=$donor_datadir --stream=xbstream --parallel=$xb_threads \
                  --encrypt-threads=$xb_enc_threads --encrypt=$xb_enc_algo --encrypt-key-file=$xb_enc_key --encrypt-chunk-size=$xb_enc_chunk"
}

donor_cmd_bbcp()
{
  cmd="bbcp -P 2 -w 2M -s 10 $donor_datadir/* $joiner_host:$joiner_datadir"
}

donor_cmd_tar()
{
  cmd="tar -cv -O $donor_datadir" 
}

donor_cmd_xbstream()
{
  cmd="-c -C $donor_datadir"
}

donor_transport_socat()
{
  transport="socat -b $socat_netbuf -u stdio TCP:$joiner_host:$joiner_port"
}

donor_transport_socat_ssl()
{
  transport="socat -b $socat_netbuf_size -u stdio openssl-connect:$socat_joiner_host:$socat_joiner_port,cert=${ssl_cert},key=${ssl_key},cafile=${ssl_ca},verify=0"
}

donor_transport_bbcp()
{
   transport="bbcp -P 2 -w $bbcp_netbuf -s $bbcp_threads  -N io \'$donor_cmd\' $joiner_host:\'$joiner_cmd\'"
}

joiner_cmd_xbstream()
{
  cmd="xbstream -x -C $joiner_datadir"
}

joiner_cmd_tar()
{
  cmd="tar -C $joiner_datadir -xf -"
}

joiner_transport_socat()
{
  transport="socat -b $socat_netbuf -u TCP-LISTEN:$joiner_port,reuseaddr stdio"  
}

joiner_transport_socat_ssl()
{
  transport="socat -b $socat_netbuf -u openssl-listen:$joiner_port,reuseaddr,cert=${ssl_cert},key=${ssl_key},cafile=${ssl_ca},verify=0  stdio"
}



#  DONOR               JOINER
#
# bbcp               = bbcp
#
# tar+socat          = socat+tar
# tar+bbcp           = bbcp+tar
#
# xbstream+socat     = socat + xbstream
# xbstream+bbcp      = bbcp + xbstream
#
# xbackup+bbcp       = bbcp+xbstream
# xbackup+socat      = socat+xbstream
#
# xbackup+enc+bbcp   = bbcp+xbstream
# xbackup+enc+socat  = socat+xbstream
#
# xbackup+socat+ssl  = socat+ssl+xbstream


usage()
{
  if [ "$1" != "" ]; then
    echo ''
    echo "ERROR: $1"
  fi

exit 1
cat << DEOF

 sst-bench: 

 Usage: sst-bench.sh options

DEOF
   exit 1
}

while test $# -gt 0; do
  case "$1" in
  --mode=*)
    MODE=$(echo "$1" | sed -e "s;--mode=;;")   ;;
  --donor-cmd=*)
    DONOR_CMD=$(echo "$1" | sed -e "s;--donor-cmd=;;")   ;;
  --joiner-cmd=*)
    JOINER_CMD=$(echo "$1" | sed -e "s;--joiner-cmd=;;")   ;;
  --transport=*)
    TRANSPORT=$(echo "$1" | sed -e "s;--transport=;;")   ;;
  --joiner-host=*)
    joiner_host=$(echo "$1" | sed -e "s;--joiner-host=;;")   ;;
  --joiner-port=*)
    joiner_port=$(echo "$1" | sed -e "s;--joiner-port=;;")   ;;
  --bbcp-netbuf=*)
    bbcp_netbuf=$(echo "$1" | sed -e "s;--bbcp-netbuf=;;")   ;;
  --bbcp-threads=*)
    bbcp_threads=$(echo "$1" | sed -e "s;--bbcp-threads=;;")   ;;
  --socat-netbuf=*)
    socat_netbuf=$(echo "$1" | sed -e "s;--socat-netbuf=;;")   ;;
  --ssl-cipher=*)
    ssl_cipher=$(echo "$1" | sed -e "s;--ssl-cipher=;;")   ;;
  --xb-threads=*)
    xb_threads=$(echo "$1" | sed -e "s;--xb-threads=;;")   ;;
  --xb-enc-algo=*)
    xb_enc_algo=$(echo "$1" | sed -e "s;--xb-enc-algo=;;")   ;;
  --xb-enc-key=*)
    xb_enc_key=$(echo "$1" | sed -e "s;--xb-enc-key=;;")   ;;
  --xb-enc-chunk=*)
    xb_enc_chunk=$(echo "$1" | sed -e "s;--xb-enc-chunk=;;")   ;;
  --xb-enc-threads=*)
    xb_enc_threads=$(echo "$1" | sed -e "s;--xb-enc-threads=;;")   ;;
  -- )  shift; break ;;
  --*) echo "Unrecognized option: $1" ; usage ;;
  * ) break ;;
  esac
  shift
done


if [ "$MODE" != "donor" -a "$MODE" != "joiner" ]; then 
   usage "Wrong mode: $MODE"
fi

if [ "$MODE" == "donor" -a "$DONOR_CMD" != "bbcp" -a  "$DONOR_CMD" != "xbstream" -a "$DONOR_CMD" != "tar" -a "$DONOR_CMD" != "xbackup" -a "$DONOR_CMD" != "xbackup_enc" ]; then 
   usage "Wrong donor_cmd: $DONOR_CMD"
fi


if [ "$MODE" == "joiner" -a "$JOINER_CMD" != "xbstream" -a "$JOINER_CMD" != "tar" -a "$JOINER_CMD" != "bbcp" ]; then 
  usage "Wrong joiner_cmd: $JOINER_CMD"
fi

if [ "$TRANSPORT" != "socat" -a "$TRANSPORT" != "socat_ssl"  -a "$TRANSPORT" != "bbcp" ]; then 
   usage "Wrong trnasport: $TRANSPORT"
fi

if [ -z "$joiner_host" ]; then 
   usage "set joiner_host"
fi

if [ -z "$joiner_port" ]; then 
   usage "set joiner_port"
fi

if [ -z "$donor_datadir" ]; then 
   usage "set donor_datadir"
fi

if [ -z "$joiner_datadir" ]; then 
   usage "set joiner_datadir"
fi

eval ${MODE}_transport_${TRANSPORT}

if [ "$MODE" == "donor" ]; then 
  eval ${MODE}_cmd_${DONOR_CMD}
  echo "DONOR CMD:"
  echo "$cmd | $transport"
else
  eval ${MODE}_cmd_${JOINER_CMD}
  echo "JOINER CMD:"
  echo "$transport | $cmd"
fi
