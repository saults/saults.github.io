#!/bin/bash
set -e


echo "Enter the password for sudo rights:"
read -s password


config=$(pwd)/${0%.*}.config
if [ ! -f $config ]; then
  echo "$config does not exist."
  exit 1
else
  source $config
fi


gsettings set org.gnome.desktop.session idle-delay 0
echo $password | sudo -S -k sed -i 's/"1"/"0"/g' /etc/apt/apt.conf.d/10periodic
echo $password | sudo -S -k sed -i 's/"1"/"0"/g' /etc/apt/apt.conf.d/20auto-upgrades
echo $password | sudo -S -k sed -i 's|http://cn.archive.ubuntu.com/ubuntu/|http://mirrors.aliyun.com/ubuntu/|g' /etc/apt/sources.list.d/ubuntu.sources


echo $password | sudo -S -k apt update
echo $password | sudo -S -k apt -y upgrade
echo $password | sudo -S -k snap refresh


#   locale_path=/etc/default/locale
#   echo $password | sudo -S -k sed -i 's/zh_CN/en_US/g' $locale_path
#   source $locale_path
#   echo $password | sudo -S -k sed -i '/^zh_CN\.UTF/s/^/# /' /etc/locale.gen
#   echo $password | sudo -S -k locale-gen --purge


apps=(ibus-libpinyin \
      gnome-music \
      totem \
      gstreamer1.0-plugins-bad \
      gstreamer1.0-plugins-ugly \
      gstreamer1.0-libav \
      libavcodec-extra \
      fragments \
      peek \
      curl \
      ffmpeg \
      gnome-boxes \
      hugo \
      trojan \
      vim \
      git \
      gnome-builder \
      appstream-util \
      cmake \
      libadwaita-1-dev \
      libsoup-3.0-dev \
      libjson-glib-dev \
      libsqlite3-dev
)
uninstalled=()
for item in ${apps[*]}; do
  if ! dpkg -s $item >/dev/null 2>&1; then
    uninstalled+=($item)
  fi
done
echo $password | sudo -S -k apt -y install $(check-language-support) ${uninstalled[*]}


if systemctl is-enabled --quiet transmission-daemon.service; then
  echo $password | sudo -S -k systemctl disable transmission-daemon.service
fi
if systemctl is-active --quiet transmission-daemon.service; then
  echo $password | sudo -S -k systemctl stop transmission-daemon.service
fi


if ! git config --get user.name; then
  git config --global user.name "zelothris"
fi
if ! git config --global user.email; then
  git config --global user.email "$git_email"
fi
if ! git config --global http.proxy; then
  git config --global http.proxy "socks5://127.0.0.1:1080"
fi
if ! git config --global init.defaultBranch; then
  git config --global init.defaultBranch master
fi


trojan_config=/etc/trojan/config.json
if ! grep -q "client" $trojan_config; then
  echo $password | sudo -S -k bash -c "cat >$trojan_config <<EOF
{
    \"run_type\": \"client\",
    \"local_addr\": \"127.0.0.1\",
    \"local_port\": 1080,
    \"remote_addr\": \"$trojan_hostname\",
    \"remote_port\": $trojan_port,
    \"password\": [
        \"$trojan_password\"
    ],
    \"log_level\": 1,
    \"ssl\": {
        \"verify\": true,
        \"verify_hostname\": true,
        \"cert\": \"\",
        \"cipher\": \"ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA:AES128-SHA:AES256-SHA:DES-CBC3-SHA\",
        \"cipher_tls13\": \"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384\",
        \"sni\": \"\",
        \"alpn\": [
            \"h2\",
            \"http/1.1\"
        ],
        \"reuse_session\": true,
        \"session_ticket\": false,
        \"curves\": \"\"
    },
    \"tcp\": {
        \"no_delay\": true,
        \"keep_alive\": true,
        \"reuse_port\": false,
        \"fast_open\": false,
        \"fast_open_qlen\": 20
    }
}
EOF"
  trojan_service=trojan.service
  if ! systemctl is-enabled --quiet $trojan_service; then
    echo $password | sudo -S -k systemctl enable $trojan_service
  fi
  if ! systemctl is-active --quiet $trojan_service; then
    echo $password | sudo -S -k systemctl start $trojan_service
  fi
fi


# about:profiles
# http://kb.mozillazine.org/User.js_file
firefox --screenshot
firefox_config_path=~/snap/firefox/common/.mozilla/firefox
firefox_profile_user=$firefox_config_path/`grep -n "^Path=" $firefox_config_path/profiles.ini | cut -f2 -d=`/user.js
if [ ! -f $firefox_profile_user ]; then
  cat >$firefox_profile_user <<EOF
user_pref("network.proxy.type", 2);
user_pref("network.proxy.autoconfig_url", "https://raw.githubusercontent.com/petronny/gfwlist2pac/master/gfwlist.pac");
user_pref("network.proxy.socks_remote_dns", true);
user_pref("network.protocol-handler.external.kiwi", false);
user_pref("network.protocol-handler.external.tg", false);
user_pref("network.protocol-handler.external.whatsapp", false);
user_pref("browser.search.region", "US");
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.showWeather", false);
user_pref("browser.newtabpage.activity-stream.topSitesRows", 4);
user_pref("doh-rollout.home-region", "US");
EOF
fi


# gsettings get org.gnome.shell favorite-apps | sed "s/\(, \)\?'thunderbird\.desktop'\|'thunderbird\.desktop'\(, \)\?//"
gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'libpinyin')]"
gsettings set com.github.libpinyin.ibus-libpinyin.libpinyin lookup-table-page-size 10
mkdir -p ~/Projects ~/.ssh ~/Pictures/Wallpapers
wget -O ~/Pictures/Wallpapers/wallpaper.jpg https://blog.kinton.cloud/pictures/wallpaper.jpg
gsettings set org.gnome.desktop.background picture-uri-dark "file://$(echo $HOME)/Pictures/Wallpapers/wallpaper.jpg"
wget -O ~/.face https://blog.kinton.cloud/pictures/avatar.jpg
busctl call org.freedesktop.Accounts /org/freedesktop/Accounts/User$(id -u) org.freedesktop.Accounts.User SetIconFile s ~/.face

echo $password | sudo -S -k reboot