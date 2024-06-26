#!/bin/bash

############################################################################################################
# 这是自动启动vultr vps的脚本，支持自动创建vps实例，自动配置vps防火墙策略，自动安装v2ray服务端，目前已经废弃，等待重构
############################################################################################################
HOME_DIR=$(cd "$(dirname "$0")" || exit; pwd)
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
    "protocol" : "tcp",
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
    "port" : "'"${V2RAY_PORT}"'",
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
    "port" : "'"${V2RAY_PORT}"'",
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
  instance_id=$1
  curl "https://api.vultr.com/v2/instances/${instance_id}" \
  -X DELETE \
  -H "Authorization: Bearer ${VULTR_API_KEY}"
}

function delete_all_vps() {
  readarray -t instance_ids < <(curl -s "https://api.vultr.com/v2/instances" \
    -X GET \
    -H "Authorization: Bearer ${VULTR_API_KEY}" | jq -r '.instances | map(.id)[]'  \
  )

  for instance_id in "${instance_ids[@]}"
  do
    delete_vps_by_id "$instance_id"
  done
}

# auto init vps by ssh
function auto_install_v2ray() {
  # 必须的参数
  check_vars  "VPS_IP" "V2RAY_PASSWORD" "V2RAY_PORT"
  if [ $? -ne 0 ]; then
    _err "VPS_IP V2RAY_PASSWORD V2RAY_PORT is required"
    exit 1
  fi

  ssh  -o StrictHostKeyChecking=no -i ~/.ssh/vultr root@"${VPS_IP}" <<-EOF
  export V2RAY_PASSWORD="${V2RAY_PASSWORD}"
  export V2RAY_PORT="${V2RAY_PORT}"
  apt-get install -y git
  rm -rf one_key_fly
  git clone https://github.com/Grebeci/one_key_fly.git
  bash  one_key_fly/v2ray_server.sh "install_v2ray"
EOF

  # 修改 v2ray-client, restart v2ray client, check v2ray client status
  sudo sed -i "s/\"address\": \".*\"/\"address\": \"$VPS_IP\"/" /usr/local/etc/v2ray/config.json
  sudo sed -i "s/\"password\": \".*\"/\"password\": \"$V2RAY_PASSWORD\"/" /usr/local/etc/v2ray/config.json
  # 修改最后一个port
  sudo tac /usr/local/etc/v2ray/config.json | sed "0,/\(\"port\":\s*\)[0-9]\+/s//\11080/" | tac > tmp && mv tmp config.json

  sudo systemctl --no-pager restart v2ray
  sudo systemctl --no-pager status v2ray

  # test proxy connect
  result=$(curl -s --proxy "socks5://127.0.0.1:1080" cip.cc )
  if [[ "$result" == *"CLOUDFLARE.COM"* ]];then
    _info "successes, connect proxy"
  else
    _err  "failed,  connect proxy"
  fi

}

# TODO
function auto_install_v2ray_in_vultr() {
  :
  # vps_firewall
  # create vps_instance
  # install v2ray
  # ping vps
}
# check user command
if ! grep -q "$1()" "$0"; then
  _err "invalid command"
  exit 1
fi
eval "$*"