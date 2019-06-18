#!/usr/bin/env bash
sudo apt install apache2 -y
sudo sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/ports.conf
sudo systemctl enable apache2
sudo systemctl start apache2