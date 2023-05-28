#!/bin/bash

HOME_DIR=$(cd "$(dirname "$0")"; pwd)
CONF_DIR=${HOME_DIR}/conf
ETC_DIR=${HOME_DIR}/etc

source ${ETC_DIR}/colorprint.sh
source ${ETC_DIR}/public_vars.sh

export VULTR_API_KEY="UYI47ZRNUUCNACVL2OBFCOCUFCLWLXTDTZGA"
export FIREWALL_GROUP_ID="27fd8237-c684-49d1-b258-d472bfce94e7"

function get_public_ip(){
  export PUBLIC_IP=$(curl -s http://httpbin.org/ip | jq -r '.origin')
  echo $PUBLIC_IP
}

function update_vps_firewall_strategy() {

  curl "https://api.vultr.com/v2/firewalls/${FIREWALL_GROUP_ID}/rules" \
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

  curl "https://api.vultr.com/v2/firewalls/${FIREWALL_GROUP_ID}/rules" \
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


  curl "https://api.vultr.com/v2/firewalls/${FIREWALL_GROUP_ID}/rules" \
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

  curl "https://api.vultr.com/v2/firewalls/${FIREWALL_GROUP_ID}/rules" \
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

export VPS_REGION_IDS=("lax" "atl" "cdg" sea)

function create_instance() {

  for region_id in "${VPS_REGION_IDS}"
  do

    # create instance 
    plan=$( \
      curl -s "https://api.vultr.com/v2/regions/lax/availability?type=vc2" \
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
        "firewall_group_id": "'"${FIREWALL_GROUP_ID}"'"
      }' \
    )

    #获取vps的各项参数
    instance_id=$(echo $instance_param | jq -r '.instance.id')
    default_password=$(echo $instance_param | jq -r '.instance.default_password')
    #sleep 60s
    
    init_after_instance_param=$( \
       curl -s "https://api.vultr.com/v2/instances/${instance_id}" \
      -X GET \
      -H "Authorization: Bearer ${VULTR_API_KEY}" \
    )

    instance_ip=$(echo $init_after_instance_param | jq -r '.instance.main_ip')

    export VPS_IP="${instance_ip}"
    
    # ping instance
    [[ $(is_ping_vps) == "failed" ]] && contintue

    # ssh-cmd-v2ray
    sshpass -p ${default_password} ssh -o "StrictHostKeyChecking=no" -T  root@${VPS_IP}  <<EOF
export CF_Key="64d8d1015e5d7d446131ea51e7054f0570846"
export CF_Email="grebeci_@outlook.com"
export LOCALNET="$(get_public_ip)/8"
export CF_TOKEN_DNS="adUcnUBfrh1y0c0bATGCRCr-xDJdbwnVuKOOpGAt"
export ZONE_ID="25b7ae690060fd9919d1dda7d914487e"
export DOMAIN="grebeci.top"
apt-get install -y git
rm -rf one_key_fly
git clone https://github.com/Grebeci/one_key_fly.git
. one_key_fly/v2ray_server.sh
install_v2ray
EOF
    
    # 修改本地v2ray,重启

    # test 连接

    # 无线循环ping + if 强制更改  
    
  done

  #连接失败
  
}
  
function is_ping_vps() {
  max_packet_loss=50

  if ping -c 10 -w 1 $VPS_IP >/dev/null; then
    packet_loss=$(echo $(ping -c 10 -w 1 $VPS_IP) | grep -oP '\d+(?=% packet loss)')
    if [ $packet_loss -gt ${max_packet_loss} ]; then
      echo "failed"
      return
  else
      echo "failed"
      return 
  fi

  echo "success"
}