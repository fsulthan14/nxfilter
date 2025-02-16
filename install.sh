#!/bin/bash

dirName=$(dirname "$0")

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

USERNAME=${1}
PARENTDIR=${2}
VERSION=${3}

# Update System
apt get -y update
DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' dist-upgrade --fix-missing

# Installing Nxfilter
${dirName}/nxfilter/install.sh ${USERNAME} ${PARENTDIR} ${VERSION}

# Enable Sudo 
${dirName}/sudo/install.sh ${USERNAME}
