
# original first 
#### todo
1. 仍未解决 Squid 无法代理 bing 问题

#### next
1. 添加usage ，增加让选择 region的方式
    - 查询可用的region
2. 增加功能： 本地iP更改，自动修改firewall

-----------------------------------

# 2024-04-10
#### solve
1. 通过TLS 隧道代理是可行的，只是当时弄反了key，pem，导致Squid代理bing （HTTPS） 不能成功。
2. 暂缓 【进行本地直接启动vps实例】开发。由于vultr的vps的实例 region 使用api无法固定，而且也拿不到最便宜的。
#### todo
1. 开发适应clash 的配置文件，同样根据 【gist】 分享。
   - 路由选择规则。
   - 代理规则。
2. DNS加密，DOH和DOT配置。
3. v2ray 、clash 启动 DOH和DOT配置




