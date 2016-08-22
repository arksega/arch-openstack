# Update system
pacman -Suy --noconfirm
pacman -S python2-pip gcc --noconfirm

# Include access tokens
. access_tokens

# Generate token initializer
openssl rand -hex 10 > keystone_admin_token

# chrony
pacman -S chrony --noconfirm
sed -ri 's/.*(server.*iburst iburst)/\1/g' /etc/chrony.conf
systemctl enable chrony.service
systemctl start chrony.service
# sleep to sync chrony
sleep 3
chronyc sources

# mariadb
pacman -S mariadb python-sqlalchemy  --noconfirm
mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
sed -i '/\[mysqld\]/a character-set-server = utf8' /etc/mysql/my.cnf
sed -i '/\[mysqld\]/a collation-server = utf8_general_ci' /etc/mysql/my.cnf
sed -i '/\[mysqld\]/a max_connections = 4096' /etc/mysql/my.cnf
sed -i '/\[mysqld\]/a innodb_file_per_table' /etc/mysql/my.cnf
sed -i '/\[mysqld\]/a default-storage-engine = innodb' /etc/mysql/my.cnf

systemctl enable mariadb.service
systemctl start mariadb.service

## mysql_secure_installation no prompt
mysql -sfu root << EOF
UPDATE mysql.user SET Password=PASSWORD('$MARIADB_PASS') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# rabbitmq
pacman -S rabbitmq --noconfirm
echo HOME=/var/lib/rabbitmq >> /etc/rabbitmq/rabbitmq-env.conf

systemctl enable rabbitmq.service
systemctl start rabbitmq.service
sleep 3

rabbitmqctl add_user openstack $RABBIT_PASS
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

# memcached
pip2 install python-memcached
pacman -S memcached --noconfirm
systemctl enable memcached.service
systemctl start memcached.service

# Openstack client
pip2 install  python-openstackclient
