#!/bin/bash

#******************************************************
# (c) 2017 Percona LLC and/or its affiliates
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
#
#*******************************************************

# mode: donor | joiner
mode="donor"

# xbackup, xbackup_enc, rsync, rsync_imporved
sst_method="tar"

# ssl: 1 enabled, anything else disabled
ssl=""

# AES NI 
aes_ni="1"

# processors count
cpu_count=$(grep -c processor /proc/cpuinfo)

# cipher suites: DEFAULT, AES128, AES256, CHACHA20
ssl_cipher="DEFAULT"

# ssl certificates
ssl_ca="/home/alexeys/sst_certs/ca.pem"
ssl_cert="/home/alexeys/sst_certs/server-cert.pem"
ssl_key="/home/alexeys/sst_certs/server-key.pem"

# joiner host/port/datadir
joiner_host="172.16.0.4"
joiner_port=20202
joiner_datadir="/data/test"

# donor datadir
donor_datadir="/data/test"

# rsync configuration file and local port
rsync_conf="/tmp/rsync.conf"
rsync_port=30303

# binaries
socat_bin="socat"
xtrabackup_bin="xtrabackup"
xbstream_bin="xbstream"

# xtrabackup encryption key
xb_enc_key="/data/sam/xb128.key"
xb_args="--host=127.0.0.1 "

#########################################################################################################################################
#########################################################################################################################################
#########################################################################################################################################

usage()
{
  if [ "$1" != "" ]; then
    echo ''
    echo "ERROR: $1"
  fi

exit 1
cat << DEOF

 sst-bench: script to test various data transfer methods used for SST in Percona XtraDB Cluster

 Usage: sst-bench.sh options

 --mode        script role: donor - push data to joiner, joiner - awating data from donor
 --sst-mode    sst-methods to test: xbackup, xbackup_enc, tar, rsync, rsync_improved
 --ssl         use ssl for network connections (defaul:0 <0|1>)
 --cipher      ssl cipher: DEFAULT, AES128, AES256, CHACHA20(for socat with openssl 1.1.0)
 --xb-enc-key  file with encryption key for xbackup_enc mode
 --aesni       AESNI enabled by default (defaul:1 <0|1>)

DEOF
   exit 1
}

while test $# -gt 0; do
  case "$1" in
  --mode=*)
    mode=$(echo "$1" | sed -e "s;--mode=;;")   ;;
  --ssl=*)
    ssl=$(echo "$1" | sed -e "s;--ssl=;;")   ;;
  --sst-mode=*)
    sst_method=$(echo "$1" | sed -e "s;--sst-mode=;;")   ;;
  --cipher=*)
    ssl_cipher=$(echo "$1" | sed -e "s;--cipher=;;")   ;;
  --xb-enc-key=*)
    xb_enc_key=$(echo "$1" | sed -e "s;--xb-enc-key=;;")   ;;
  --aesni=*)
    aes_ni=$(echo "$1" | sed -e "s;--aesni=;;")   ;;
  -- )  shift; break ;;
  --*) echo "Unrecognized option: $1" ; usage ;;
  * ) break ;;
  esac
  shift
done


if [ "$mode" != "donor" -a "$mode" != "joiner" ]; then 
   usage "Wrong mode: $mode"
fi

if [ "$sst_method" != "xbackup" -a  "$sst_method" != "xbackup_enc" -a "$sst_method" != "rsync" -a "$sst_method" != "rsync_improved" -a "$sst_method" != "tar" ]; then 
   usage "Wrong donor_cmd: $sst_method"
fi

if [ "$sst_method" == "xbackup_enc" -a  "$ssl_cipher" != "AES128" -a "$ssl_cipher" != "AES256" ]; then 
   usage "Wrong ssl_cipher : $ssl_cipher  for xbackup_enc mode. Supported only AES128, AES256"
fi


if [ "$ssl_cipher" != "DEFAULT" -a  "$ssl_cipher" != "AES128" -a "$ssl_cipher" != "AES256"  -a "$ssl_cipher" != "CHACHA20" ]; then 
   usage "Wrong ssl_cipher: $ssl_cipher. Supported: DEFAULT, AES128, AES256, CHACHA20"
fi


if [ "$mode" == "donor" -a ! -d "$donor_datadir" ]; then 
  usage "Can't access donor data dir: $donor_datadir"
fi

if [ "$mode" == "joiner" -a ! -d "$joiner_datadir" ]; then 
  usage "Can't access donor data dir: $joiner_datadir"
fi


if [ "$mode" == "joiner" -a -d ${joiner_datadir} ]; then 

  echo "Cleaning up joiner datadir for test"
  #rm -rf ${joiner_datadir}/*
fi

# Drop caches
sudo su -c "echo 3 > /proc/sys/vm/drop_caches"
sync

if [ -n "$aes_ni" -a  "$aes_ni" == "0" ]; then 
  echo "Disabling AES_NI"
  socat_prefix='/usr/bin/env OPENSSL_ia32cap="~0x200000200000000"'
fi

    if [ "$ssl" == "1" ]; then 
    
      socat_joiner_transport="openssl-listen:${joiner_port},reuseaddr,cipher=${ssl_cipher},cert=${ssl_cert},key=${ssl_key},cafile=${ssl_ca},verify=0"
      socat_donor_transport="openssl-connect:${joiner_host}:${joiner_port},cipher=${ssl_cipher},cert=${ssl_cert},key=${ssl_key},cafile=${ssl_ca},verify=0"
      rsync_host="127.0.0.1"
    else
      socat_joiner_transport="tcp-listen:${joiner_port},reuseaddr "
      socat_donor_transport="tcp:${joiner_host}:${joiner_port}"
      rsync_host=${joiner_host}
    fi

if [ "$mode" == "joiner" ]; then 

  if [ "$sst_method" == "xbackup" ]; then 

    echo "${socat_prefix} ${socat_bin} -u ${socat_joiner_transport} stdio | ${xbstream_bin} -x -C ${joiner_datadir}"
    ${socat_prefix} ${socat_bin} -u ${socat_joiner_transport} stdio | ${xbstream_bin} -x -C ${joiner_datadir}

  elif [ "$sst_method" == "xbackup_enc" ]; then

    echo "${socat_prefix} ${socat_bin} -u tcp-listen:${joiner_port},reuseaddr stdio |${xbstream_bin} -x -C ${joiner_datadir}
    time ${xtrabackup_bin}  --decrypt=${ssl_cipher} --parallel=4 --encrypt-threads=${cpu_count} --encrypt-key-file=${xb_enc_key} --target-dir=${joiner_datadir}"

    ${socat_prefix} ${socat_bin} -u tcp-listen:${joiner_port},reuseaddr stdio |${xbstream_bin} -x -C ${joiner_datadir}
    time ${xtrabackup_bin}  --decrypt=${ssl_cipher} --parallel=4 --encrypt-threads=${cpu_count} --encrypt-key-file=${xb_enc_key} --target-dir=${joiner_datadir}

  elif [ "$sst_method" == "tar" ]; then

     echo "${socat_prefix} ${socat_bin} -u ${socat_joiner_transport} stdio | tar -C ${joiner_datadir} -xf -"
     ${socat_prefix} ${socat_bin} -u ${socat_joiner_transport} stdio | tar -C ${joiner_datadir} -xf -

  elif [ "$sst_method" == "rsync" -o "$sst_method" == "rsync_improved"  ]; then

      trap 'echo "Test was interrupted by Control-C at line $LINENO."; \
                   killall ${socat_bin} > /dev/null 2>&1 ; killall rsync >/dev/null 2>&1;  exit' INT

      if [ "$ssl" == "1" ] ; then
         echo "/usr/bin/env ${socat_prefix} ${socat_bin} ${socat_joiner_transport},fork,pf=ip4  TCP4:127.0.0.1:${rsync_port} &"
         /usr/bin/env ${socat_prefix} ${socat_bin} "${socat_joiner_transport},fork,pf=ip4" TCP4:127.0.0.1:${rsync_port} &
      fi

    cat << EOF > "$rsync_conf"
pid file = /tmp/rsync_sst.pid
use chroot = no
read only = no
timeout = 300
[rsync_sst]
    path = $joiner_datadir
EOF

    if [ -f "/tmp/rsync_sst.pid" ]; then 
       rm -f /tmp/rsync_sst.pid
    fi
    echo "rsync --daemon  --no-detach --address ${rsync_host} --port ${rsync_port} --config=${rsync_conf}"

    rsync --daemon  --no-detach --address ${rsync_host} --port ${rsync_port} --config=${rsync_conf}
  fi
elif [ "$mode" == "donor" ]; then

  if [ "$sst_method" == "xbackup" ]; then 
 
    echo "time ${socat_prefix} ${xtrabackup_bin} ${xb_args} --backup --datadir=${donor_datadir} --stream=xbstream --parallel=4 | ${socat_bin} -u stdio  ${socat_donor_transport}"

    time ${socat_prefix} ${xtrabackup_bin} ${xb_args} --backup --datadir=${donor_datadir} --stream=xbstream --parallel=4 | ${socat_bin} -u stdio  ${socat_donor_transport}

  elif [ "$sst_method" == "xbackup_enc" ]; then

    echo " time ${socat_prefix} ${xtrabackup_bin} ${xb_args} --backup --datadir=${donor_datadir} --stream=xbstream --parallel=4 \
    --encrypt-threads=${cpu_count} --encrypt=${ssl_cipher} --encrypt-key-file=${xb_enc_key}| ${socat_bin} -u stdio TCP:${joiner_host}:${joiner_port}"

    time ${socat_prefix} ${xtrabackup_bin} ${xb_args} --backup --datadir=${donor_datadir} --stream=xbstream --parallel=4 \
    --encrypt-threads=${cpu_count} --encrypt=${ssl_cipher} --encrypt-key-file=${xb_enc_key}| ${socat_bin} -u stdio TCP:${joiner_host}:${joiner_port}

  elif [ "$sst_method" == "tar" ]; then

    echo "time (cd  ${donor_datadir} && ${socat_prefix} tar -cO *  | ${socat_bin} -u stdio  ${socat_donor_transport} )"
    time (cd  ${donor_datadir} && ${socat_prefix} tar -cO *  | ${socat_bin} -u stdio  ${socat_donor_transport} )


  elif [ "$sst_method" == "rsync" -o "$sst_method" == "rsync_improved" ]; then

    if [ "$ssl" == "1" ] ; then    
       echo "    /usr/bin/env ${socat_prefix} ${socat_bin} TCP4-LISTEN:${rsync_port},reuseaddr,fork  ${socat_donor_transport},pf=ip4 & "
       /usr/bin/env ${socat_prefix} ${socat_bin} TCP4-LISTEN:${rsync_port},reuseaddr,fork  "${socat_donor_transport},pf=ip4"  &
       socat_pid=$!
    fi
    
    if [ "$sst_method" == "rsync" ]; then 

      echo "time ( rsync -aLP --owner --group --perms --links --specials --ignore-errors \
                -f '+ /ib_lru_dump' -f '+ /ibdata*' -f '+ /ib_logfile*' -f '+ */'  -f'+ /*/' -f'- *'\
                   ${donor_datadir}/ rsync://${rsync_host}:${rsync_port}/rsync_sst; cd ${donor_datadir} ;  \
             find . -maxdepth 1 -mindepth 1 -type d -print0 | xargs -I{} -0 -P${cpu_count} \
             rsync --owner --group --perms --links --specials  --ignore-times --inplace --recursive --delete --quiet \
                     --whole-file  ${donor_datadir}/{}/  rsync://${rsync_host}:${rsync_port}/rsync_sst/{} 2>/dev/null)"

      time ( rsync -aLP --owner --group --perms --links --specials --ignore-errors \
                -f '+ /ib_lru_dump' -f '+ /ibdata*' -f '+ /ib_logfile*' -f '+ */'  -f"+ /*/" -f"- *"\
                   ${donor_datadir}/ rsync://${rsync_host}:${rsync_port}/rsync_sst; cd ${donor_datadir} ;  \
             find . -maxdepth 1 -mindepth 1 -type d -print0 | xargs -I{} -0 -P${cpu_count} \
             rsync --owner --group --perms --links --specials  --ignore-times --inplace --recursive --delete --quiet \
                     --whole-file  ${donor_datadir}/{}/  rsync://${rsync_host}:${rsync_port}/rsync_sst/{} 2>/dev/null)
    else
      echo "time ( rsync -aLP --owner --group --perms --links --specials \
              --ignore-times --inplace --dirs -f '+ */' -f'+ /*/' -f'- *' ${donor_datadir}/* \
                   rsync://${rsync_host}:${rsync_port}/rsync_sst;  cd ${donor_datadir} ; \
             find . -mount -type f -path './*/*' -print0 ,  -path './ibdata1' -print0 , -path './ib_l*' -print0  | \
             xargs -0 -n1 -P10 -I% rsync --owner --group --perms --links --specials --archive --ignore-errors --whole-file --ignore-times --quiet \
                  --inplace --delete  % rsync://${rsync_host}:${rsync_port}/rsync_sst/% 2>/dev/null )"

      time ( rsync -aLP --owner --group --perms --links --specials \
              --ignore-times --inplace --dirs -f '+ */' -f'+ /*/' -f'- *' ${donor_datadir}/* \
                   rsync://${rsync_host}:${rsync_port}/rsync_sst;  cd ${donor_datadir} ; \
             find . -mount -type f -path './*/*' -print0 ,  -path './ibdata1' -print0 , -path './ib_l*' -print0  | \
             xargs -0 -n1 -P10 -I% rsync --owner --group --perms --links --specials --archive --ignore-errors --whole-file --ignore-times --quiet \
                  --inplace --delete  % rsync://${rsync_host}:${rsync_port}/rsync_sst/% 2>/dev/null )

    fi

    if [ -n "$socat_pid" ]; then 
       kill -15  $socat_pid
    fi
  fi

fi
