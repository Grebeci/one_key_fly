#!/bin/bash

HOME_DIR=$(cd "$(dirname "$0")"; pwd)
CONF_DIR=${HOME_DIR}/conf
ETC_DIR=${HOME_DIR}/etc

source ${ETC_DIR}/colorprint.sh

export SQUID_HTTPS_PORT="22806"
export DOMAIN="grebeci.top"
export LOCALNET="219.143.130.34/8"


function init_vps() {
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
    [[ -f /usr/local/etc/v2ray/config.json ]] && rm -f /usr/local/etc/v2ray/config.json
    cp ${CONF_DIR}/config.json /usr/local/etc/v2ray/config.json

    #防火墙
    ufw allow 60822
    ufw status

    # 安装wrap : 针对 chatGPT,new bing 隐藏地理位置
    curl https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" |  tee /etc/apt/sources.list.d/cloudflare-client.list
    
    apt-get update
    apt-get -y install cloudflare-warp
    [[ "$(warp-cli status)" == *"Connected"*  ]] && warp-cli delete
    echo y | warp-cli register
    warp-cli set-mode proxy  # 必须先启动代理，如果参考官网上的跳过这个，本地ssh/ping就会连不到vps了
    warp-cli connect


    service  v2ray restart
    sleep 5s 
    systemctl --no-pager status v2ray
    if [[ $? -eq 0 ]]; then
      _info "v2ray successed ......."
    else
      _error "v2ray failed ......." && exit 1
    fi

    sleep 5s

    if [[ -z "$(curl chat.openai.com --proxy socks5://127.0.0.1:40000)" ]]; then 
      _info "wrap successed "
    else
      _error "wrap failed" && exit 3
    fi 

    # vps status
    _info "current vps IP" 
    echo  -e "$(curl -s cip.cc)"
    _info "cloudfare wrap IP "
    echo -e "$(curl -s --proxy socks5://127.0.0.1:40000 cip.cc)"  
}

function build_squid_server_for_debian() {
  echo 1 > /proc/sys/net/ipv4/ip_forward
  apt install squid -y
  [[ -f /etc/squid/squid.conf ]] && rm -rf /etc/squid/squid.conf
  cp ${CONF_DIR}/squid.conf /etc/squid/squid.conf

  # Configurating Squid 
  rm -rf /etc/squid/conf.d/*
  # 1. SSL configuration for Squid 
  apply_SSL_cert_by_acme
cat << EOF > /etc/squid/conf.d/port.conf
https_port "${SQUID_HTTPS_PORT}" tls-cert=/etc/ssl/certs/grebeci.top.cert tls-key=/etc/ssl/certs/grebeci.top.key
EOF
  
  # 2. allow IP pass 
cat << EOF > /etc/squid/conf.d/acl.conf
acl localnet src ${LOCALNET}
EOF

  # 3. user auth
  rm -rf /etc/squid/passwords
  htpasswd -cd /etc/squid/passwords squid
cat << EOF > /etc/squid/conf.d/auth.conf
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwords
auth_param basic children 5
auth_param basic realm Squid proxy-caching web server
auth_param basic credentialsttl 30 minutes
auth_param basic casesensitive on
acl ncsa_users proxy_auth REQUIRED
http_access allow ncsa_users
EOF

  # start & test 
  systemctl restart squid.service
  systemctl status  squid.service

  curl -v --proxy https://grebeci.top:"${SQUID_HTTPS_PORT}" google.com

}

# 通过acme 申请SSL证书，dns api方式， dns为 cf
function apply_SSL_cert_by_acme() {
  
  [[ -d /root/.acme ]] && rm -rf /root/.acme
  curl "https://get.acme.sh" | sh -s 

  alias acme.sh='bash /root/.acme.sh/acme.sh'

  export CF_Key="64d8d1015e5d7d446131ea51e7054f0570846"
  export CF_Email="grebeci_@outlook.com"

  acme.sh --set-default-ca --server letsencrypt --force \
          --issue --dns dns_cf  -d grebeci.top -d www.grebeci.top \
          --accountemail grebeci_@outlook.com

  acme.sh --installcert -d grebeci.top \
          --key-file /etc/ssl/certs/grebeci.top.key  \
          --cert-file /etc/ssl/certs/grebeci.top.cert \
          --fullchain-file /etc/ssl/certs/grebeci.top.cert \
          --ca-file /etc/ssl/certs/ca.cer
}

init_vps && build_v2ray_server_for_debian