#!/usr/bin/env bash
if [ $(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
    sudo apt install apache2 -y
    sudo sed -i 's/Listen 80$/Listen 8080/g' /etc/apache2/ports.conf
    sudo systemctl enable apache2
    sudo systemctl restart apache2
fi
