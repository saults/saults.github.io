#!/bin/bash
set -e


config=$(pwd)/${0%.*}.config
if [ ! -f $config ]; then
  echo "$config does not exist."
  exit 1
else
  source $config
fi


if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
  echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
fi
if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
  echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
fi
sysctl -p


apt update
apps=(shadowsocks-v2ray-plugin \
      nginx \
      socat \
      curl
)
uninstalled=()
for item in ${apps[*]}; do
  if ! dpkg -s $item >/dev/null 2>&1; then
    uninstalled+=($item)
  fi
done
apt -y install ${uninstalled[*]}
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --version v4.45.2
# bash <(curl -fsSL https://git.io/hysteria.sh)


ss_config=/etc/shadowsocks-libev/config.json
cat >$ss_config <<EOF
{
  "server":["0.0.0.0"],
  "mode":"tcp_and_udp",
  "server_port":30086,
  "local_port":1080,
  "password":"$shadowsocks_password",
  "timeout":86400,
  "method":"chacha20-ietf-poly1305",
  "plugin":"ss-v2ray-plugin",
  "plugin_opts":"server;path=/ss"
}
EOF
systemctl restart shadowsocks-libev.service


v2ray_config=/usr/local/etc/v2ray/config.json
cat >$v2ray_config <<EOF
{
  "inbounds": [{
    "port": 10000,
    "listen":"127.0.0.1",
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "$v2ray_id",
          "level": 1,
          "alterId": 0
        }
      ]
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "/ray"
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  },{
    "protocol": "blackhole",
    "settings": {},
    "tag": "blocked"
  }],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF
if ! systemctl is-enabled --quiet v2ray.service; then
  systemctl enable v2ray.service
fi
if ! systemctl is-active --quiet v2ray.service; then
  systemctl start v2ray.service
fi


mkdir -p /etc/nginx/conf
openssl req -x509 -nodes -days 36500 -newkey rsa:2048 -subj "/C=CN/ST=Jiangsu/L=Nanjing/O=digitalocean.kinton.cloud/CN=digitalocean.kinton.cloud/emailAddress=i@kinton.cloud" -keyout /etc/nginx/conf/private.key.pem -out /etc/nginx/conf/domain.cert.pem


# sed 's/\(^[\t ]*[^#][\t ]*\)\(listen .*80 default_server;\)/\1# \2/' default
# sed 's/\(^[\t ]*\)# \(listen .*443 ssl default_server;\)/\1\2/' default
# grep -n "^server {" default | cut -f1 -d:
# sed 's/\(^[\t ]*\)\(# listen .\+443 ssl default_server;\)/\1\2\
# \1ssl_certificate \/etc\/nginx\/conf\/domain.cert.pem;\
# \1ssl_certificate_key \/etc\/nginx\/conf\/private.key.pem;/' default
# sed 's/\(server_name[\t ]*\).*\(;\)/\1digitalocean.kinton.cloud\2/' default
# grep -Pzo "(?s)(?<=\n)[\t ]*location[\t ]*/[\t ]*\{.*?\}[\t ]*\n" default | wc -l
nginx_config=/etc/nginx/sites-available/default
cat >$nginx_config <<EOF
server {
	listen 80 default_server;
	server_name $nginx_server_name;
	return 301 https://\$server_name\$request_uri;
}
server {
	listen 443 ssl default_server;
	ssl_certificate /etc/nginx/conf/domain.cert.pem;
	ssl_certificate_key /etc/nginx/conf/private.key.pem;
	
	root /var/www/html;

	index index.html index.htm index.nginx-debian.html;

	server_name $nginx_server_name;

	location / {
		try_files \$uri \$uri/ =404;
	}
	location /ray {
		proxy_redirect off;
		proxy_intercept_errors on;
		proxy_pass http://127.0.0.1:10000;
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \$http_host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	}
	location /ss {
		proxy_redirect off;
		proxy_intercept_errors on;
		proxy_pass http://127.0.0.1:30086;
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \$http_host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	}
}
EOF
systemctl restart nginx.service


curl https://get.acme.sh | sh -s email=$user_email
source ~/.bashrc
acme.sh --issue -d $nginx_server_name --webroot /var/www/html --server letsencrypt --force
acme.sh --install-cert -d $nginx_server_name \
--key-file /etc/nginx/conf/private.key.pem \
--fullchain-file /etc/nginx/conf/domain.cert.pem \
--reloadcmd "service nginx force-reload"