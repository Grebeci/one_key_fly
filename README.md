# one-key-fly
v2ray 服务器快速初始化

# 使用方式
#### in vps shell  
```
export DOMAIN="grebeci.top"
export CF_Key=""
export CF_Email=""
export LOCALNET=""
export CF_TOKEN_DNS=""
export ZONE_ID=""
export VULTR_API_KEY=""
export V2RAY_PASSWORD=""
```
bash v2ray_server.sh "install_v2ray"

#### in local (linux)
```
export DOMAIN="grebeci.top"
export CF_Key=""
export CF_Email=""
export LOCALNET=""
export CF_TOKEN_DNS=""
export ZONE_ID=""
export VULTR_API_KEY=""
export V2RAY_PASSWORD=""
# export REGION_ID=("sea" "lax" "atl" "cdg")
export REGION_ID="atl"  
```
bash auto_vps_for_vultr.sh "create_instace"



# todo
1. 仍未解决 Squid 无法代理 bing 问题

# next
1. 添加usage ，增加让选择 region的方式
    - 查询可用的region
2. 增加功能： 本地iP更改，自动修改firewall

