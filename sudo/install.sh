#!/bin/bash

# only root should execute this script
if [ "$EUID" -ne 0 ]
then
  echo "[ERROR] Please run as root..."
  echo
  exit 1
fi

echo
if [ "$#" -lt 1 ]; then
   echo [ERROR] Wrong number of arguments
   echo "Syntax is:"
   echo "   ${0} <nxfilter-username>"
   echo
   exit 1
fi

echo
echo "[INFO] Exec ${0}"
echo

echo "[INFO] Add sudo to start/stop nxfilter service"

dirName=$(dirname "$0")
USERNAME=${1}

# remove previous IaC entries
sed "s/{USER_NAME}/${USERNAME}/g" ${dirName}/nxfilter.sudo >/etc/sudoers.d/${USERNAME}

echo "[INFO] New sudo rights successfully added for nxfilter"
