#!/bin/bash

# Pastikan script dijalankan sebagai root
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] This script must be run as root!" >&2
  exit 1
fi

# Cek jumlah argumen
if [ "$#" -lt 3 ]; then
   echo "[ERROR] Wrong number of arguments"
   echo "Syntax is:"
   echo "   ${0} <nxfilter-username> <nxfilter-dir> <nxfilter-version>"
   exit 1
fi

echo
echo "[INFO] Exec ${0} ${1} ${2} ${3}"
echo

# Variabel utama
dirName=$(dirname "$0")
USERNAME="${1}"
PARENTDIR="${2}"
VERSION="${3}" # Misal: 4.7.1.4

# Hapus service lama jika ada
if systemctl is-enabled nxfilter 2>/dev/null | grep -q "masked"; then
    echo "[WARNING] nxfilter.service is masked, unmasking..."
    systemctl unmask nxfilter
fi

if [ -f "/etc/systemd/system/nxfilter.service" ]; then
    systemctl disable --now nxfilter
    rm "/etc/systemd/system/nxfilter.service"
fi

# Instalasi dependencies
echo "[INFO] Installing Dependencies..."
apt-get update -y
DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' dist-upgrade --fix-missing
apt-get install unzip openjdk-8-jre-headless -y

# Buat user nxfilter
echo "[INFO] Creating Nxfilter User..."
mkdir -p "${PARENTDIR}/${USERNAME}"
if id "${USERNAME}" &>/dev/null; then
    userdel -rf "${USERNAME}" &>/dev/null
fi
if getent group "${USERNAME}" &>/dev/null; then
    groupdel "${USERNAME}" &>/dev/null
fi
groupadd "${USERNAME}"
useradd -m -s /bin/bash -d "${PARENTDIR}/${USERNAME}" -u 1100 -g "${USERNAME}" "${USERNAME}"

# Nonaktifkan systemd-resolved untuk DNS
echo "[INFO] Disabling systemd-resolved DNS..."
systemctl stop systemd-resolved
systemctl disable systemd-resolved
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Download dan install NxFilter
echo "[INFO] Downloading & Installing Nxfilter..."
NXFILTER="nxfilter-${VERSION}.zip"
cd "${PARENTDIR}/${USERNAME}" || exit 1
wget "https://pub.nxfilter.org/${NXFILTER}"
unzip "${NXFILTER}"
rm "${NXFILTER}" "${PARENTDIR}/${USERNAME}/bin/"*.bat
chmod +x "${PARENTDIR}/${USERNAME}/bin/"*
chown -R "${USERNAME}:${USERNAME}" "${PARENTDIR}/${USERNAME}"

# Konfigurasi Setcap untuk Java
echo "[INFO] Enabling Setcap for Java..."
JAVA_BIN=$(realpath "$(which java)")
if [[ -L "${JAVA_BIN}" ]]; then
    JAVA_BIN=$(readlink -f "${JAVA_BIN}") # Ikuti symlink jika ada
fi
setcap 'cap_net_bind_service=+ep' "${JAVA_BIN}"

# Buat service NxFilter
echo "[INFO] Creating Nxfilter Service..."
SERVICE_FILE="/etc/systemd/system/nxfilter.service"
TEMPLATE_FILE="/tmp/nxfilter/nxfilter/nxfilter.service"

# Pastikan template file ada sebelum sed dijalankan
if [[ ! -f "${TEMPLATE_FILE}" ]]; then
    echo "[ERROR] Template file ${TEMPLATE_FILE} not found!"
    exit 1
fi

sed -e "s|{NXFILTER_USER}|${USERNAME}|g" -e "s|{WORK_DIR}|${PARENTDIR}|g" "${TEMPLATE_FILE}" > "${SERVICE_FILE}"

# Reload systemd dan enable service
systemctl daemon-reload
systemctl enable --now nxfilter

echo "[INFO] Done!"

