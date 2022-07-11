#!/bin/bash

sudo su -

echo "178.124.206.53 wp.k8s-17.sa wp.k8s-18.sa" >> /etc/hosts

wget https://repo.zabbix.com/zabbix/6.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.2-1+ubuntu20.04_all.deb
dpkg -i zabbix-release_6.2-1+ubuntu20.04_all.deb
apt -y update
apt install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent -y
apt install mysql-server -y

#database - zabbix | db user - zabix | db password - password

echo "create database zabbix character set utf8mb4 collate utf8mb4_bin;" > /tmp/create_zabbix.sql
echo "create user zabbix@localhost identified by 'password';" >> /tmp/create_zabbix.sql
echo "grant all privileges on zabbix.* to zabbix@localhost;" >> /tmp/create_zabbix.sql
echo "FLUSH PRIVILEGES;" >> /tmp/create_zabbix.sql

zcat /usr/share/doc/zabbix-sql-scripts/mysql/server.sql.gz | mysql -u root -p zabbix

sed -i "s|# DBPassword=|DBPassword=password|g" /etc/zabbix/zabbix_server.conf

systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2
