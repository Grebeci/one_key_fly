#!/bin/bash

HOME_DIR=$(cd "$(dirname "$0")"; pwd)
CONF_DIR=${HOME_DIR}/conf
ETC_DIR=${HOME_DIR}/etc

SERVER_PORT=60822
SS_CLIENT=60822
PRIVOXY_PORT=22806

source ${ETC_DIR}/colorprint.sh

function init_vps() {
    yum -y install epel-release
    yum -y install python-pip
}

function build_ss_client_for_centos() {
    pip install https://github.com/shadowsocks/shadowsocks/archive/master.zip
    
    [[ -f "/etc/shadowsocks.json" ]] && rm -rf /etc/shadowsocks.json
    cp  ${CONF_DIR}/shadowsocks.json /etc/shadowsocks.json
    

    #privoxy 
    yum -y install privoxy
    yum install -y libsodium

    sed -i  's/listen-address  127.0.0.1:8118/listen-address  0.0.0.0:22806/' /etc//privoxy/config
    sed -i  's/#        forward-socks5t   \/               127.0.0.1:9050 ./forward-socks5t   \/               127.0.0.1:60822 ./' /etc/privoxy/config


    [[ -f "/etc/systemd/system/shadowsocks.service" ]] && rm -rf /etc/systemd/system/shadowsocks.service
cat << EOF >  /etc/systemd/system/shadowsocks.service
    [Unit]
    Description=Shadowsocks
    [Service]
    TimeoutStartSec=0
    ExecStart=/usr/bin/sslocal -c /etc/shadowsocks.json --libsodium /usr/lib64/libsodium.so.23
    [Install]
    WantedBy=multi-user.target
EOF
   

}