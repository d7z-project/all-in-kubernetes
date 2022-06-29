# 备份旧的配置
mv /etc/apt/sources.list /etc/apt/sources.list.bak
# 覆盖新的配置文件
cat << EOF > /etc/apt/sources.list
deb https://mirrors.ustc.edu.cn/debian/ bullseye main contrib non-free
deb https://mirrors.ustc.edu.cn/debian/ bullseye-updates main contrib non-free
deb https://mirrors.ustc.edu.cn/debian/ bullseye-backports main contrib non-free
deb https://mirrors.ustc.edu.cn/debian-security/ bullseye-security main contrib non-free
EOF
