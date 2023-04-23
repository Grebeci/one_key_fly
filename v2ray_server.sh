#!/bin/bash

HOME_DIR=$(cd "$(dirname "$0")"; cd ..; pwd)
CONF_DIR=${HOME_DIR}/conf
LOG_DIR=${HOME_DIR}/log
SCRIPT_DIR=${HOME_DIR}/script
ETC_DIR=${HOME_DIR}/etc

source ${ETC_DIR}/colorprint.sh

function init_vps() {
    :
cat << EOF >  /etc/sysctl.conf
	fs.file-max = 655350
	net.core.default_qdisc=fq
	net.ipv4.tcp_congestion_control=bbr
EOF
}

function build_v2ray_server_for_debian() {
    # 安装 v2ray
    apt-get install -y curl
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
    cp ${CONF_DIR}/conf.json /usr/local/etc/config.json

    #防火墙
    ufw status
    ufw allow 60822

    # 安装wrap : 针对 chatGPT,new bing 隐藏地理位置
    curl https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" |  tee /etc/apt/sources.list.d/cloudflare-client.list
    apt install cloudflare-warp
    warp-cli register
    warp-cli set-mode proxy  # 必须先启动代理，如果参考官网上的跳过这个，本地ssh/ping就会连不到vps了
    warp-cli connect

    service v2ray restart
    service v2ray status
    if [[ $? -eq 0 ]]; then
      _info "v2ray successed ......."
    else
      _error "v2ray failed ......."
    fi

    curl myip.ipip.net --proxy socks5://127.0.0.1:40000
}

function build_v2ray_server_for_centos() {
  :
}

init_vps && build_v2ray_server_for_debian