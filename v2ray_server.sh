#!/bin/bash
shopt -s expand_aliases

HOME_DIR=$(cd "$(dirname "$0")"; pwd)
CONF_DIR=${HOME_DIR}/conf
ETC_DIR=${HOME_DIR}/etc

source ${ETC_DIR}/colorprint.sh
source ${ETC_DIR}/public_vars.sh

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
    sed -i "s/\"port\": 60822,/\"port\": ${V2RAY_POER},/g"  /usr/local/etc/v2ray/config.json

    #防火墙
    ufw allow ${V2RAY_POER}
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
https_port ${SQUID_HTTPS_PORT} tls-cert=/etc/ssl/certs/grebeci.top.cert tls-key=/etc/ssl/certs/grebeci.top.key
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

  # firewall  
  ufw allow ${SQUID_HTTPS_PORT}/tcp 
  ufw allow ${SQUID_HTTPS_PORT}/udp
  ufw status

  # start 
  systemctl restart squid.service
  systemctl status  squid.service
}

function build_nginx_server_for_debian() {

}

# 通过acme 申请SSL证书，dns api方式， dns为 cf
function apply_SSL_cert_by_acme() {
  
  [[ -d /root/.acme ]] && rm -rf /root/.acme
  curl "https://get.acme.sh" | sh -s 
  
  /root/.acme.sh/acme.sh --set-default-ca --server ZeroSSL --force \
          --issue --dns dns_cf  -d ${DOMAIN} -d www.${DOMAIN} \
          --accountemail ${CF_Email}

  /root/.acme.sh/acme.sh --installcert -d grebeci.top \
          --key-file /etc/ssl/certs/grebeci.top.key  \
          --cert-file /etc/ssl/certs/grebeci.top.cert \
          --fullchain-file /etc/ssl/certs/grebeci.top.pem \
          --ca-file /etc/ssl/certs/ca.cer
}

function bind_domain_for_vps() {
  apt-get install -y jq
  # 取DNS解析的 Record ID
  record_id=$( \
    curl -s --request GET \
      --url https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records \
      --header 'Content-Type: application/json' \
      --header "Authorization: Bearer ${CF_TOKEN_DNS}" \
      | jq -r '.result[] | select(.type == "A") | .id' \
    )

  vps_ip=$(curl -s https://httpbin.org/ip | jq -r '.origin')

  curl -s --request PUT \
    --url https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${record_id} \
    --header "Authorization: Bearer ${CF_TOKEN_DNS}" \
    --header 'Content-Type: application/json' \
    --data '{
    "content": "'"${vps_ip}"'" ,
    "name": "'"${DOMAIN}"'",
    "proxied": true,
    "type": "A",
    "comment": "Domain verification record",
    "ttl": 3600
    }'
}

function install_all() {
  init_vps && build_v2ray_server_for_debian && build_squid_server_for_debian && bind_domain_for_vps
}

function install_v2ray(){
   init_vps && build_v2ray_server_for_debian && bind_domain_for_vps
}