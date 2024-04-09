# one-key-fly
v2ray 服务器快速初始化(支持TLS)

# 使用方式

in vps shell  

```bash
sudo apt-get update
sudo apt-get install -y git
git clone https://github.com/Grebeci/one_key_fly.git
```

```
export DOMAIN="grebeci.top"
export CF_TOKEN_DNS=""
export ZONE_ID=""
export CF_Key=""
export CF_Email=""
export GIST_V2RAY_TOKEN=""
export GIST_ID=""
```

```bash
bash install_v2ray.sh "install_v2ray_TLS"
```

