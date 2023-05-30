#!/bin/bash

HOME_DIR=$(cd "$(dirname "$0")"; pwd)
CONF_DIR=${HOME_DIR}/conf
ETC_DIR=${HOME_DIR}/etc

source ${ETC_DIR}/colorprint.sh
source ${ETC_DIR}/public_vars.sh
check_vars

firewall_group_id=""

function get_public_ip(){
  export PUBLIC_IP=$(curl -s http://httpbin.org/ip | jq -r '.origin')
  echo $PUBLIC_IP
}

function create_vps_firewall_strategy() {

  firewall_group_id=$(\
    curl -s "https://api.vultr.com/v2/firewalls" \
    -X POST \
    -H "Authorization: Bearer ${VULTR_API_KEY}" \
    -H "Content-Type: application/json" \
    --data '{
      "description" : "'"$(date '+%Y-%m-%d %H:%M:%S')"'"
    }' | jq -r '.firewall_group.id'
  )


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

function create_instance() {
    
  # create instance 
  plan=$( \
    curl -s "https://api.vultr.com/v2/regions/${REGION_ID}/availability?type=vc2" \
    -X GET \
    -H "Authorization: Bearer ${VULTR_API_KEY}" |  jq -r '.available_plans[0]' \
  )

  create_vps_firewall_strategy
  
  init_instance_param=$( \
    curl -s "https://api.vultr.com/v2/instances" \
    -X POST \
    -H "Authorization: Bearer ${VULTR_API_KEY}" \
    -H "Content-Type: application/json" \
    --data '{
      "region" : "'"${REGION_ID}"'",
      "plan" : "'"${plan}"'",
      "label" : "proxy",
      "os_id" : 477,
      "backups" : "disabled",
      "hostname": "proxy",
      "firewall_group_id": "'"${firewall_group_id}"'"
    }' \
  )

  [[ $(echo $init_instance_param | grep -q "error") ]] && _err "create instance failed" &&  exit 1 

  #获取vps的各项参数
  instance_id=$(echo $init_instance_param | jq -r '.instance.id')
  default_password=$(echo $init_instance_param | jq -r '.instance.default_password')
    
  sleep 60s
    
  init_after_instance_param=$( \
      curl -s "https://api.vultr.com/v2/instances/${instance_id}" \
    -X GET \
    -H "Authorization: Bearer ${VULTR_API_KEY}" \
  )

  [[ $(echo $init_after_instance_param | grep -q "error") ]] && _err "create instance failed" &&  exit 1 
  instance_ip=$(echo $init_after_instance_param | jq -r '.instance.main_ip')
  vps_ip="${instance_ip}"
  
  # ping instance
  [[ $(is_ping_vps) == "failed" ]] && _err "ping failed " &&  exit 1 

  sleep 120s

  # ssh-cmd-v2ray
  ssh-keygen -f "/home/grebeci/.ssh/known_hosts" -R "$vps_ip"
  sshpass -p ${default_password} ssh -o "StrictHostKeyChecking=no" -T  root@${vps_ip}  <<EOF
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
  sed -i "s/\"address\": \".*\"/\"address\": \"$vps_ip\"/" /usr/local/etc/v2ray/config.json
  sed -i "s/\"password\": \".*\"/\"password\": \"$V2RAY_PASSWORD\"/" /usr/local/etc/v2ray/config.json
  # 修改最后一个port
  tac /usr/local/etc/v2ray/config.json | sed "0,/\(\"port\":\s*\)[0-9]\+/s//\11080/" | tac > tmp && mv tmp config.json

  sudo systemctl restart v2ray 
  sudo systemctl status v2ray

  # test proxy connect
  proxy_ip=$(curl  --proxy "socks5://127.0..0.1:1080" http://httpbin.org/ip | jq -r '.origin')
  if [[ "$proxy_ip" -eq "$vps_ip" ]];then
    _info "successed!!! conect proxy" 
  else
    _err  "failed !! conect proxy" && exit 3
  fi
  
}
  
function is_ping_vps() {
  max_packet_loss=50

  # 运行 ping 命令并提取丢包率
  packet_loss=$(echo $(ping -c 20 -w 30 $vps_ip) | grep -oP '\d+(\.\d+)?(?=% packet loss)')

  # 检查丢包率是否大于最大丢包率
  if [ $(echo "$packet_loss > $max_packet_loss" | bc) -eq 1 ]; then
    # 如果丢包率大于最大丢包率，打印失败消息
    echo "failed"
    return
  fi

  echo "success"
}

function delete_vps_by_id() {
  instance-id=$1
  curl "https://api.vultr.com/v2/instances/${instance-id}" \
  -X DELETE \
  -H "Authorization: Bearer ${VULTR_API_KEY}"
}

function delete_all_vps() {
  instance_ids=curl "https://api.vultr.com/v2/instances" \
    -X GET \
    -H "Authorization: Bearer ${VULTR_API_KEY}"
}

create_instance