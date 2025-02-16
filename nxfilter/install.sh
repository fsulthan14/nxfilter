#!/bin/bash

dirName=$(dirname "$0")
USERNAME="${1}"
PARENTDIR="${2}"
VERSION=${3} # 4.7.1.4

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] This script must be run as root!" >&2
  exit 1
fi

# Delete service
if [ -f /etc/systemd/system/${USERNAME}.service ]; then
	systemctl disable --now ${USERNAME}
	rm /etc/systemd/system/${USERNAME}.service
fi

# Installing Dependencies
echo "[INFO] Installing Dependencies.."
apt update && apt upgrade -y
apt install unzip curl cron openjdk-8-jre-headless -y

# Create Users..
echo "[INFO] Create Nxfilter User.."
mkdir -p ${PARENTDIR}/${USERNAME}
id ${USERNAME} &> /dev/null && userdel -rf ${USERNAME} &>/dev/null
getent group ${USERNAME} &> /dev/null && groupdel ${USERNAME} &>/dev/null
groupadd ${USERNAME}
useradd -m -s /bin/bash -d ${PARENTDIR}/${USERNAME} -u 1100 -g ${USERNAME} ${USERNAME}

# Disable DNS Systemd
echo "[INFO] Disabling DNS.."
service systemd-resolved stop
systemctl disable systemd-resolved
rm /etc/resolv.conf
sh -c "echo nameserver 8.8.8.8 > /etc/resolv.conf"

# Installing NXFilter
echo "[INFO] Download & Installing Nxfilter.."
NXFILTER="nxfilter-${VERSION}.zip"
cd ${PARENTDIR}/${USERNAME}
wget https://pub.nxfilter.org/${NXFILTER}
unzip ${PARENTDIR}/${USERNAME}/${NXFILTER}
rm ${PARENTDIR}/${USERNAME}/${NXFILTER} ${PARENTDIR}/${USERNAME}/bin/*.bat
chmod +x ${PARENTDIR}/${USERNAME}/bin/*
chown -R ${USERNAME}.${USERNAME} ${PARENTDIR}/${USERNAME}

# Enable Setcap
JAVA_BIN=$(readlink -f $(which java))
setcap 'cap_net_bind_service=+ep' ${JAVA_BIN}

# Create nxfilter service
sed -e "s|{NXFILTER_USER}|${USERNAME}|g" -e "s|{WORK_DIR}|${PARENTDIR}/${USERNAME}|g" ${dirName}/${USERNAME}.service > /etc/systemd/system/${USERNAME}.service
systemctl daemon-reload
systemctl enable --now ${USERNAME}
