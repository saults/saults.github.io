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


echo $password | sudo -S -k apt update
echo $password | sudo -S -k apt -y upgrade
echo $password | sudo -S -k snap refresh


locale_path=/etc/default/locale
echo $password | sudo -S -k sed -i 's/zh_CN/en_US/g' $locale_path
source $locale_path
echo $password | sudo -S -k sed -i '/^zh_CN\.UTF/s/^/# /' /etc/locale.gen
echo $password | sudo -S -k locale-gen --purge


apps=(ibus-libpinyin \
      totem \
      gstreamer1.0-plugins-bad \
      gstreamer1.0-plugins-ugly \
      gstreamer1.0-libav \
      libavcodec-extra \
      curl \
      ffmpeg \
      gnome-boxes \
      hugo \
      peek \
      shadowsocks-v2ray-plugin \
      vim \
      git \
      gnome-builder \
      appstream-util \
      cmake \
      libadwaita-1-dev \
      libsoup-3.0-dev \
      libjson-glib-dev
)
uninstalled=()
for item in ${apps[*]}; do
  if ! dpkg -s $item >/dev/null 2>&1; then
    uninstalled+=($item)
  fi
done
echo $password | sudo -S -k apt -y install $(check-language-support) ${uninstalled[*]}


if ! git config --get user.name; then
  git config --global user.name "SriCook"
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


v2ray_config=/etc/shadowsocks-libev/DigitalOcean.json
if [ ! -f $v2ray_config ]; then
  echo $password | sudo -S -k bash -c "cat >$v2ray_config <<EOF
{
  \"server\":[\"$v2ray_server\"],
  \"mode\":\"tcp_and_udp\",
  \"server_port\":443,
  \"local_address\":\"0.0.0.0\",
  \"local_port\":1080,
  \"password\":\"$v2ray_password\",
  \"timeout\":86400,
  \"method\":\"chacha20-ietf-poly1305\",
  \"plugin\":\"ss-v2ray-plugin\",
  \"plugin_opts\":\"tls;host=$v2ray_server;path=/ss;loglevel=none\"
}
EOF"
  v2ray_service=shadowsocks-libev-local@DigitalOcean
  if ! systemctl is-enabled --quiet $v2ray_service; then
    echo $password | sudo -S -k systemctl enable $v2ray_service
  fi
  if ! systemctl is-active --quiet $v2ray_service; then
    echo $password | sudo -S -k systemctl start $v2ray_service
  fi
fi


# about:profiles
# http://kb.mozillazine.org/User.js_file
firefox --screenshot
firefox_config_path=~/snap/firefox/common/.mozilla/firefox
firefox_profile_user=$firefox_config_path/`grep -n "^Path=" $firefox_config_path/profiles.ini | cut -f2 -d=`/user.js
if [ ! -f $firefox_profile_user ]; then
  cat >$firefox_profile_user <<EOF
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("network.proxy.type", 2);
user_pref("network.proxy.autoconfig_url", "https://raw.githubusercontent.com/petronny/gfwlist2pac/master/gfwlist.pac");
user_pref("network.proxy.socks_remote_dns", true);
user_pref("network.protocol-handler.external.kiwi", false);
user_pref("network.protocol-handler.external.tg", false);
user_pref("network.protocol-handler.external.whatsapp", false);
EOF
fi


# gsettings get org.gnome.shell favorite-apps | sed "s/\(, \)\?'thunderbird\.desktop'\|'thunderbird\.desktop'\(, \)\?//"
gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'libpinyin')]"
gsettings set com.github.libpinyin.ibus-libpinyin.libpinyin lookup-table-page-size 10
mkdir ~/Projects ~/.ssh ~/Pictures/Wallpapers
wget -O ~/Pictures/Wallpapers/wallpaper.jpg https://blog.kinton.cloud/pictures/wallpaper.jpg
gsettings set org.gnome.desktop.background picture-uri-dark "file://$(echo $HOME)/Pictures/Wallpapers/wallpaper.jpg"
wget -O ~/.face https://blog.kinton.cloud/pictures/avatar.png
busctl call org.freedesktop.Accounts /org/freedesktop/Accounts/User$(id -u) org.freedesktop.Accounts.User SetIconFile s ~/.face

echo $password | sudo -S -k reboot