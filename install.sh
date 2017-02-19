#!/bin/sh

printf "\n########\n\🎵Chip Audio Station 🎵\n\n########\n\n"

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "Station name (for Airplay and Spotify):"
read stationname

# Basic update
printf "\n########\n\nUpdating system...\n\n########\n\n"
apt-get update
apt-get -y upgrade

apt-get install -y locales
locale-gen en_US en_US.UTF-8
sudo dpkg-reconfigure locales
# Dependencies
printf "\n########\n\nInstalling dependencies...\n\n########\n\n"
apt-get install -y autoconf libtool libdaemon-dev libasound2-dev libpopt-dev \
    libconfig-dev avahi-daemon libavahi-client-dev libssl-dev git build-essential unzip

# Config file
printf "\n########\n\nCreating config...\n\n########\n\n"
CONFIGTEXT="general = {
  name = \"$stationname\";
  interpolation = \"soxr\";
};

alsa = {
  output_device = \"hw:0\";
  mixer_control_name = \"Power Amplifier\";
};
"

echo $CONFIGTEXT | sudo tee /etc/shairport-sync.conf

# Download
printf "\n########\n\nRetrieving shairport repo...\n\n########\n\n"
git clone https://github.com/mikebrady/shairport-sync.git

# Setup
printf "\n########\n\nConfiguring...\n\n########\n\n"
cd shairport-sync
git checkout development
autoreconf -i -f
./configure --with-alsa --with-avahi --with-ssl=openssl --with-systemd --with-soxr

# Build
printf "\n########\n\nBuilding...\n\n########\n\n"
make

# Systemd config (Note: does not seem to work in shell script, must be done manually)
printf "\n########\n\nCreating user...\n\n########\n\n"
getent group shairport-sync &>/dev/null || sudo groupadd -r shairport-sync >/dev/null
getent passwd shairport-sync &> /dev/null || sudo useradd -r -M -g shairport-sync -s /usr/bin/nologin -G audio shairport-sync >/dev/null

# Install
printf "\n########\n\nInstalling...\n\n########\n\n"
make install

sed -i.bak '/Group=shairport-sync/a Nice=-15' /lib/systemd/system/shairport-sync.service
rm /lib/systemd/system/shairport-sync.service.bak

# Enable at startup
printf "\n########\n\nConfiguring systemd...\n\n########\n\n"
systemctl enable shairport-sync
systemctl start shairport-sync

printf "\n########\n\nInstalling librespot (Spotify connect)...\n\n########\n\n"
wget https://github.com/herrernst/librespot/releases/download/v20161230-7fd8503/librespot-linux-armhf-raspberry_pi.zip
unzip librespot-linux-armhf-raspberry_pi.zip -d /usr/bin
rm librespot-linux-armhf-raspberry_pi.zip

wget https://raw.githubusercontent.com/plietar/librespot/master/assets/librespot.service -O /etc/systemd/system/librespot.service

sed -i "s/%p on %H/$stationname/g" /etc/systemd/system/librespot.service
systemctl enable librespot.service
systemctl start librespot.service

printf "\n########\n\nRemoving ubihealthd debug logging\n\n########\n\n"
sed -i "s/ExecStart=\/usr\/sbin\/ubihealthd/ExecStart=\/usr\/sbin\/ubihealthd -v 1/g" /etc/systemd/system/ubihealthd.service
systemctl restart ubihealthd

printf "\n########\n\nAll done 😁\n\n########\n\n"
