# Include access tokens
. access_tokens

# Root path
root_path=$(pwd)

# Create kesytone db and user
mysql -u root -p$MARIADB_PASS << EOF
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';
EOF

# Generate token initializer
openssl rand -hex 10 > keystone_admin_token

# Install keystone from source
git clone https://git.openstack.org/openstack/keystone.git
pacman -S apache --noconfirm
cd keystone;
git checkout stable/mitaka
pip2 install . pymysql -c ../mitaka-constrains.txt
useradd -r -s /usr/bin/nologin keystone -m

# Populate /etc
mkdir /etc/keystone
cd etc
cp keystone.conf.sample /etc/keystone/keystone.conf
cp logging.conf.sample /etc/keystone/logging.conf
cp default_catalog.templates keystone-paste.ini policy.json sso_callback_template.html /etc/keystone
cd $root_path

# Configure keystone
sed -i "/^\[DEFAULT\]/a admin_token = $(cat keystone_admin_token)" /etc/keystone/keystone.conf
sed -i "/^\[database\]/a connection = mysql+pymysql://keystone:$KEYSTONE_DBPASS@$HOSTNAME/keystone" /etc/keystone/keystone.conf
sed -i "/^\[token\]/a provider = fernet" /etc/keystone/keystone.conf

su -s /bin/sh -c "keystone-manage db_sync" keystone
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone

# Install apache
pacman -S apache mod_wsgi2 --noconfirm
sed -i "s/#ServerName.*/ServerName $HOSTNAME/" /etc/httpd/conf/httpd.conf
cp wsgi-keystone.conf /etc/httpd/conf/extra/wsgi-keystone.conf
sed -i "/^#Include conf\/extra\/httpd-ssl.conf.*/a Include conf\/extra\/wsgi-keystone.conf" /etc/httpd/conf/httpd.conf
sed -i "/^#LoadModule rewrite_module.*/a LoadModule wsgi_module modules/mod_wsgi.so" /etc/httpd/conf/httpd.conf
sed -i 's/apache2/httpd/g' /etc/httpd/conf/extra/wsgi-keystone.conf
systemctl enable httpd.service
systemctl start httpd.service

# Create services, and endpoints
# ===============
# At this point all should by up and running

export OS_TOKEN=$(cat keystone_admin_token)
export OS_URL=http://$HOSTNAME:35357/v3
export OS_IDENTITY_API_VERSION=3

echo 'Create service entity'
openstack service create \
	  --name keystone --description "OpenStack Identity" identity

echo 'Create public identity endpoint'
openstack endpoint create --region RegionOne \
	   identity public http://$HOSTNAME:5000/v3

echo 'Create internal identity endpoint'
openstack endpoint create --region RegionOne \
	   identity internal http://$HOSTNAME:5000/v3

echo 'Create admin identity endpoint'
openstack endpoint create --region RegionOne \
	   identity admin http://$HOSTNAME:5000/v3

# Create domain, projects, users and roles

echo 'Create default domain'
openstack domain create --description "Default Domain" default

echo 'Create admin project'
openstack project create --domain default --description "Admin Project" admin

echo 'Create admin user'
openstack user create --domain default --password $ADMIN_PASS admin

echo 'Create admin role'
openstack role create admin

echo 'Link admin role to admin user and project'
openstack role add --project admin --user admin admin

echo 'Create service project'
openstack project create --domain default --description "Service Project" service

echo 'Create demo project'
openstack project create --domain default --description "Demo Project" demo

echo 'Create demo user'
openstack user create --domain default --password $DEMO_PASS demo

echo 'Create user role'
openstack role create user

echo 'Link user role to demo user and project'
openstack role add --project demo --user demo user

echo '============================='
echo 'Test request...'
unset OS_TOKEN OS_URL
OS_PASSWORD=$ADMIN_PASS openstack --os-auth-url http://$HOSTNAME:35357/v3 \
	  --os-project-domain-name default --os-user-domain-name default \
	    --os-project-name admin --os-username admin token issue
