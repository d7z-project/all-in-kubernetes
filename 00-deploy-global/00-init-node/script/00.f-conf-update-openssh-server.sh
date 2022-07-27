#!/usr/bin/env bash
# 更新OpenSSH 配置文件
cat << "EOF" > /etc/ssh/sshd_config.d/security.conf
# 修改默认SSH端口
Port 2222
# 开启公钥登陆
PubkeyAuthentication yes
# 指定公钥位置
AuthorizedKeysFile     .ssh/authorized_keys
# 关闭密码登陆
PasswordAuthentication no
EOF

# 重加载配置文件
systemctl restart ssh
