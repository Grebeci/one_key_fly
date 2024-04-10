#!/bin/bash

############################################################################################################
#  自动化配置v2ray服务端端脚本，支持TLS
#  nginx -> v2ray(TLS) -> warp -> internet
#  v2ray 客户端配置文件通过 gist 分享
# 
#  
#  约定配置项：
#  TLS : Domain, CF_Email, CF_Key, CF_TOKEN_DNS, ZONE_ID
#  V2RAY: V2RAY_ID(随机生成)
#  client config: GIST_V2RAY_TOKEN, GIST_ID
############################################################################################################

shopt -s expand_aliases
# 错误停止
set -e 
set -o pipefail

# install necessary tools
apt-get update 2>&1 > /dev/null
apt-get install -y curl ufw uuid jq net-tools 2>&1 > /dev/null

HOME_DIR=$(cd "$(dirname "$0")"; pwd)
CONF_DIR=${HOME_DIR}/conf
UTILS_DIR=${HOME_DIR}/utils

source ${UTILS_DIR}/v2ray_public_vars.sh
source ${UTILS_DIR}/colorprint.sh

# V2RAY_ID
if [ ! -f /tmp/v2ray_id ]; then
    echo "$(uuid)" > /tmp/v2ray_id
fi
V2RAY_ID=$(cat /tmp/v2ray_id)

# bbr, time zone
function init_vps() {

    # PS1 color
    sed -i 's/^\(.*PS1=.*\)$/#\1/' ~/.bashrc
    echo 'PS1="\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ "' >>  ~/.bashrc
    source  ~/.bashrc

    # bbr
    # 1. exit if bbr already enabled
    sed -i '/fs.file-max/d' /etc/sysctl.conf
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf

    # 2. add bbr
    cat << EOF >  /etc/sysctl.conf
    fs.file-max = 655350
    net.core.default_qdisc=fq
    net.ipv4.tcp_congestion_control=bbr
EOF
    sysctl -p &> /dev/null
    _info "bbr successes ......."
    
    # Time zone
    sudo timedatectl set-timezone Asia/Shanghai
    date -R
}

function install_v2ray() {

    _info "install v2ray ......."

    check_vars V2RAY_ID 
    # install v2ray

    # 1. download and install v2ray
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) 2>&1 > /dev/null
    
    # 2. config v2ray 主要是修改v2ray_id
    [[ -f /usr/local/etc/v2ray/config.json ]] && rm -f /usr/local/etc/v2ray/config.json

    cp "${CONF_DIR}"/config.json /usr/local/etc/v2ray/config.json

    jq --arg v2ray_id "${V2RAY_ID}" \
        '.inbounds[0].settings.clients[0].id = $v2ray_id' /usr/local/etc/v2ray/config.json > temp.json
    mv temp.json /usr/local/etc/v2ray/config.json
}


function install_warp() {

    _info "install wrap ......."

    # 安装wrap : 针对 chatGPT,new bing 隐藏地理位置
    curl https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg 
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" |  tee /etc/apt/sources.list.d/cloudflare-client.list
    
    apt-get update 2>&1 > /dev/null
    apt-get -y install cloudflare-warp 2>&1 > /dev/null

    [[ "$(warp-cli --accept-tos status )" != *"Registration Missing"* ]] && warp-cli --accept-tos delete 
    echo y | warp-cli  --accept-tos register
    warp-cli --accept-tos  set-mode proxy  # 必须先启动代理，如果参考官网上的跳过这个，本地ssh/ping就会连不到vps了
    warp-cli --accept-tos connect 

    sleep 5s

    if [[ $? -eq 0 ]]; then
        _info "wrap successes ......."
    else
        _error "wrap failed ......." && exit 3
    fi
}

# 绑定vps_ip到域名，先删除所有的A记录，再添加新的A记录
function bind_domain() {
    check_vars DOMAIN CF_TOKEN_DNS ZONE_ID

    vps_ip=$(curl -s https://httpbin.org/ip | jq -r '.origin')

    # 取DNS解析的 Record ID
    record_ids=$( \
        curl -s --request GET \
            --url https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records \
            --header 'Content-Type: application/json' \
            --header "Authorization: Bearer ${CF_TOKEN_DNS}" \
            | jq -r '.result[] | select(.type == "A") | .id' \
    )

    # 删除所有的A记录
    for id in $record_ids; do
        curl -s --request DELETE \
            --url https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${id} \
            --header "Authorization: Bearer ${CF_TOKEN_DNS}" \
            --header 'Content-Type: application/json'
    done

    # 添加A记录
    is_success=$( \
        curl -s --request POST \
            --url https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records \
            --header "Authorization: Bearer ${CF_TOKEN_DNS}" \
            --header 'Content-Type: application/json' \
            --data '{
            "type": "A",
            "name": "'"${DOMAIN}"'",
            "content": "'"${vps_ip}"'",
            "ttl": 120,
            "comment": "Domain verification record"
        }'
    )

    # 等待DNS生效
    sleep 120s

    if [[ $(echo $is_success | jq -r '.success') == "true" ]]; then
        _info "bind domain successes ......."
    else
        _error "bind domain failed ......." && exit 4
    fi

    _info "bind domain successes ......."

}


function apply_SSL_cert() {

    # 检查SSL 证书是否过期，如果没有过期，则不需要重新申请
    if [[ -f /etc/ssl/certs/${DOMAIN}.pem ]]; then
        expire_date=$(openssl x509 -enddate -noout -in /etc/ssl/certs/${DOMAIN}.pem | cut -d= -f 2)
        expire_date=$(date -d "${expire_date}" +%s)
        now_date=$(date +%s)
        if [[ $expire_date -gt $now_date ]]; then
            _info "SSL cert is not expired, no need to apply ......."
            return
        fi
    fi

    # 安装 SSL 证书
    check_vars DOMAIN CF_Email CF_Key

    # 1. 安装 acme.sh
    [[ -d /root/.acme ]] && rm -rf /root/.acme
    curl "https://get.acme.sh" | sh -s 2>&1 > /dev/null

    # 2. 申请SSL证书，dns_sleep=300(实验值)
    /root/.acme.sh/acme.sh --set-default-ca --server ZeroSSL --force  \
        --issue --dns dns_cf  -d ${DOMAIN} -d www.${DOMAIN} --accountemail ${CF_Email} --dnssleep 300

    if [[ $? -ne 0 ]]; then
        _error "apply SSL cert failed ......." && exit 5
    fi

    # 3. 安装SSL证书
    /root/.acme.sh/acme.sh --installcert -d ${DOMAIN} \
        --key-file /etc/ssl/certs/${DOMAIN}.key  \
        --fullchain-file /etc/ssl/certs/${DOMAIN}.pem 

    _info "apply SSL cert successes ......."
}


function install_nginx() {
    apt-get install -y nginx

    # config nginx
    [[ -f /etc/nginx/nginx.conf ]] && rm -f /etc/nginx/nginx.conf

    cp "${CONF_DIR}"/nginx.conf /etc/nginx/nginx.conf

    sed -i "s@server_name.*mydomain.me;@server_name           ${DOMAIN};@" /etc/nginx/nginx.conf
}

# 经验是，启动顺序是先启动nginx，再启动v2ray
function start_sevice() {

    # 1. start ufw
    ufw allow 443/tcp
    ufw allow 443/udp
    ufw status
    
    # 1. start nginx
    systemctl restart nginx
    systemctl --no-pager status nginx

    if [[ $? -eq 0 ]]; then
        _info "nginx successes ......."
    else
        _error "nginx failed ......." && exit 6
    fi
    
    # 3. start v2ray
    systemctl restart v2ray
    sleep 5s 
    systemctl --no-pager status v2ray

    if [[ $? -eq 0 ]]; then
        _info "v2ray successes ......."
    else
        _error "v2ray failed ......." && exit 1
    fi

    # test verify
    if curl -iv https://${DOMAIN} 2>&1 | grep -q "HTTP/1.1 200 OK"; then
        _info "verify successes ......."
    else
        _error "verify failed ......."
        exit 7
    fi
}

# 客户端配置文件通过 https://gist.github.com 分享
function distribute_client_config() {
    
    check_vars GIST_V2RAY_TOKEN GIST_ID V2RAY_ID

    # 1. 生成客户端配置文件，同步 v2ray_id
    content=$(cat ${CONF_DIR}/v2ray_clinet_conf.json | jq --arg v2ray_id "${V2RAY_ID}" \
        '.outbounds[0].settings.vnext[0].users[0].id = $v2ray_id' )
    
    # Gist 的描述和文件内容
    GIST_DESC="v2ray client config $(date +'%Y-%m-%d %H:%M:%S')"
    FILE_NAME="config.json"
    FILE_CONTENT=$(echo "${content}" | jq )

    # 创建 JOSN 数据
    JSON_DATA=$(jq -n \
    --arg description "$GIST_DESC" \
    --arg filename "$FILE_NAME" \
    --arg content "$FILE_CONTENT" \
    '{
        "description": $description,
        "files": {
        ($filename): {
            "content": $content
        }
        }
    }')

    # 2. 上传到 gist
    result=$( \
        curl -X PATCH  \
            -H "Authorization: token ${GIST_V2RAY_TOKEN}" \
            https://api.github.com/gists/${GIST_ID} \
            -d "$JSON_DATA" \
        )

    # 3. 获取gist的url
    gist_url=$(echo $result | jq -r '.files["config.json"].raw_url')

    _info "client config url: ${gist_url}"

}

function install_v2ray_TLS() {
    init_vps

    install_v2ray
    install_warp

    bind_domain
    apply_SSL_cert
    
    install_nginx

    start_sevice
    distribute_client_config

}

eval "$*"