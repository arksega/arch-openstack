# Include access tokens
. access_tokens

## Create kesytone db and user
#mysql -u root -p$MARIADB_PASS << EOF
#CREATE DATABASE keystone;
#GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';
#GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';
#EOF
#
## Generate token initializer
#openssl rand -hex 10 > keystone_admin_token
#
## Install keystone from source
#git clone https://git.openstack.org/openstack/keystone.git
#(cd keystone; pip install .)
#useradd -r -s /usr/bin/nologin keystone
#mkdir /etc/keystone
#cp keystone/etc/keystone.conf.sample /etc/keystone/keystone.conf
#
## Configure keystone
#sed -i "/^\[DEFAULT\]/a admin_token = $(cat keystone_admin_token)" /etc/keystone/keystone.conf
#sed -i "/^\[database\]/a connection = mysql+pymysql://keystone:$KEYSTONE_DBPASS@$HOSTNAME/keystone" /etc/keystone/keystone.conf
#sed -i "/^\[token\]/a provider = fernet" /etc/keystone/keystone.conf
#
#su -s /bin/sh -c "keystone-manage db_sync" keystone
#keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
#
## Install apache
#pacman -S apache mod_wsgi --noconfirm
sed -i "s/#ServerName.*/ServerName $HOSTNAME/" /etc/httpd/conf/httpd.conf
cp keystone/httpd/wsgi-keystone.conf /etc/httpd/conf/extra/wsgi-keystone.conf
#sed -i "/^#Include conf\/extra\/httpd-ssl.conf.*/a Include conf\/extra\/wsgi-keystone.conf" /etc/httpd/conf/httpd.conf
#sed -i "/^#LoadModule rewrite_module.*/a LoadModule wsgi_module modules/mod_wsgi.so" /etc/httpd/conf/httpd.conf
sed -i 's/apache2/httpd/g' /etc/httpd/conf/extra/wsgi-keystone.conf
systemctl enable httpd.service
systemctl start httpd.service
