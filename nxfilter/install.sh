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

if [ "$#" -lt 3 ]; then
   echo [ERROR] Wrong number of arguments
   echo "Syntax is:"
   echo "   ${0} <nxfilter-username> <nxfilter-dir> <nxfilter-version>"
   echo
   exit 1
fi

echo
echo "[INFO] Exec ${0} ${1} ${2} ${3}"
echo

# Delete service
if [ -f /etc/systemd/system/${USERNAME}.service ]; then
	systemctl disable --now ${USERNAME}
	rm /etc/systemd/system/${USERNAME}.service
fi

# Installing Dependencies
echo "[INFO] Installing Dependencies.."
DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' dist-upgrade --fix-missing
apt install unzip openjdk-8-jre-headless -y

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
echo "[INFO] Enabling Setcap.."
JAVA_BIN=$(readlink -f $(which java))
setcap 'cap_net_bind_service=+ep' ${JAVA_BIN}

# Create nxfilter service
echo "[INFO] Create Nxfilter Service.."
sed -e "s|{NXFILTER_USER}|${USERNAME}|g" -e "s|{WORK_DIR}|${PARENTDIR}/${USERNAME}|g" ${dirName}/nxfilter..service > /etc/systemd/system/nxfilter.service
systemctl daemon-reload
systemctl enable --now ${USERNAME}

echo "[INFO] Done"
