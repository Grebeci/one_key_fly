#!/bin/bash

HOME_DIR=$(cd "$(dirname "$0")"; pwd)
CONF_DIR=${HOME_DIR}/conf
ETC_DIR=${HOME_DIR}/etc

source ${ETC_DIR}/colorprint.sh
source ${ETC_DIR}/public_vars.sh
check_vars

firewall_group_id="27fd8237-c684-49d1-b258-d472bfce94e7"

function get_public_ip(){
  export PUBLIC_IP=$(curl -s http://httpbin.org/ip | jq -r '.origin')
  echo $PUBLIC_IP
}

function update_vps_firewall_strategy() {

  curl "https://api.vultr.com/v2/firewalls/${firewall_group_id}/rules" \
  -X POST \
  -H "Authorization: Bearer ${VULTR_API_KEY}" \
  -H "Content-Type: application/json" \
  --data '{
    "ip_type" : "v4",
    "protocol" : "ICMP",
    "port" : "",
    "subnet" : "'"$(get_public_ip)"'",
    "subnet_size" : 24,
    "source" : "",
    "notes" : "ping"
  }'

  curl "https://api.vultr.com/v2/firewalls/${firewall_group_id}/rules" \
  -X POST \
  -H "Authorization: Bearer ${VULTR_API_KEY}" \
  -H "Content-Type: application/json" \
  --data '{
    "ip_type" : "v4",
    "protocol" : "SSH",
    "port" : "22",
    "subnet" : "'"$(get_public_ip)"'",
    "subnet_size" : 24,
    "source" : "",
    "notes" : "SSH"
  }'


  curl "https://api.vultr.com/v2/firewalls/${firewall_group_id}/rules" \
  -X POST \
  -H "Authorization: Bearer ${VULTR_API_KEY}" \
  -H "Content-Type: application/json" \
  --data '{
    "ip_type" : "v4",
    "protocol" : "tcp",
    "port" : "'"${V2RAY_POER}"'",
    "subnet" : "'"$(get_public_ip)"'",
    "subnet_size" : 24,
    "source" : "",
    "notes" : "v2ray"
  }'

  curl "https://api.vultr.com/v2/firewalls/${firewall_group_id}/rules" \
  -X POST \
  -H "Authorization: Bearer ${VULTR_API_KEY}" \
  -H "Content-Type: application/json" \
  --data '{
    "ip_type" : "v4",
    "protocol" : "udp",
    "port" : "'"${V2RAY_POER}"'",
    "subnet" : "'"$(get_public_ip)"'",
    "subnet_size" : 24,
    "source" : "",
    "notes" : "v2ray"
  }'

  curl "https://api.vultr.com/v2/firewalls/${firewall_group_id}/rules" \
    -X POST \
    -H "Authorization: Bearer ${VULTR_API_KEY}" \
    -H "Content-Type: application/json" \
    --data '{
      "ip_type" : "v4",
      "protocol" : "tcp",
      "port" : "'"${SQUID_HTTPS_PORT}"'",
      "subnet" : "'"$(get_public_ip)"'",
      "subnet_size" : 24,
      "source" : "",
      "notes" : "Squid"
    }'

  curl "https://api.vultr.com/v2/firewalls/${firewall_group_id}/rules" \
  -X POST \
  -H "Authorization: Bearer ${VULTR_API_KEY}" \
  -H "Content-Type: application/json" \
  --data '{
    "ip_type" : "v4",
    "protocol" : "udp",
    "port" : "'"${SQUID_HTTPS_PORT}"'",
    "subnet" : "'"$(get_public_ip)"'",
    "subnet_size" : 24,
    "source" : "",
    "notes" : "Squid"
  }'
}

VPS_REGION_IDS=("sea" "lax" "atl" "cdg")

function create_instance() {

  for region_id in "${VPS_REGION_IDS}"
  do

    # create instance 
    plan=$( \
      curl -s "https://api.vultr.com/v2/regions/${region_id}/availability?type=vc2" \
      -X GET \
      -H "Authorization: Bearer ${VULTR_API_KEY}" |  jq -r '.available_plans[0]' \
    )

    update_vps_firewall_strategy
    
    init_instance_param=$( \
      curl -s "https://api.vultr.com/v2/instances" \
      -X POST \
      -H "Authorization: Bearer ${VULTR_API_KEY}" \
      -H "Content-Type: application/json" \
      --data '{
        "region" : "'"${region_id}"'",
        "plan" : "'"${plan}"'",
        "label" : "proxy",
        "os_id" : 477,
        "backups" : "disabled",
        "hostname": "proxy",
        "firewall_group_id": "'"${firewall_group_id}"'"
      }' \
    )

    [[ echo $instance_param | grep -q "error" ]] && contintue

    #获取vps的各项参数
    instance_id=$(echo $instance_param | jq -r '.instance.id')
    default_password=$(echo $instance_param | jq -r '.instance.default_password')
    
    sleep 60s
    
    init_after_instance_param=$( \
       curl -s "https://api.vultr.com/v2/instances/${instance_id}" \
      -X GET \
      -H "Authorization: Bearer ${VULTR_API_KEY}" \
    )

    [[ echo $init_after_instance_param | grep -q "error" ]] && contintue
    instance_ip=$(echo $init_after_instance_param | jq -r '.instance.main_ip')
    vps_id="${instance_ip}"
    
    # ping instance
    [[ $(is_ping_vps) == "failed" ]] && contintue

    # ssh-cmd-v2ray
    sshpass -p ${default_password} ssh -o "StrictHostKeyChecking=no" -T  root@${vps_id}  <<EOF
export CF_Key="${CF_Key}"
export CF_Email="${CF_Email}"
export LOCALNET="$(get_public_ip)/8"
export CF_TOKEN_DNS="${CF_TOKEN_DNS}"
export ZONE_ID="${ZONE_ID}"
export DOMAIN="${DOMAIN}"
export V2RAY_PASSWORD="${V2RAY_PASSWORD}"

apt-get install -y git
rm -rf one_key_fly
git clone https://github.com/Grebeci/one_key_fly.git
bash one_key_fly/v2ray_server.sh "install_v2ray"
EOF
    
    # 修改v2ray, restart v2ray, check v2ray status
    sudo sed -i "s/\"address\": \".*\"/\"address\": \"$vps_id\"/" /usr/local/etc/v2ray/config.json
    sudo sed -i "s/\"password\": \".*\"/\"password\": \"$V2RAY_PASSWORD\"/" /usr/local/etc/v2ray/config.json
    sudo sed -i "s/\"port\": .*/\"port\": $V2RAY_POER/" /usr/local/etc/v2ray/config.json

    sudo systemctl start v2ray
    sudo systemctl status v2ray

    # test 连接
    proxy_ip=$(curl  --proxy "socks5://127.0..0.1:1080" http://httpbin.org/ip | jq -r '.origin')
    [[ $proxy_ip -eq $vps_id ]] && _info "conect proxy" 

    # 无线循环ping + if 强制更改  
    while true;
    do
      if [[ $(is_ping_vps) == "success" ]];then
        sleep 10s
      else 
        break
      fi 
    done

  
  done

  # 建立代理失败
  _err "尝试了所有vps，均失败"
  
}
  
function is_ping_vps() {
  max_packet_loss=50

  if ping -c 10 -w 1 $vps_id >/dev/null; then
    packet_loss=$(echo $(ping -c 10 -w 1 $vps_id) | grep -oP '\d+(?=% packet loss)')
    if [ $packet_loss -gt ${max_packet_loss} ]; then
      echo "failed"
      return
    fi
  else
      echo "failed"
      return 
  fi

  echo "success"
}

create_instance