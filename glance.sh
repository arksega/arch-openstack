# Include access tokens
. admin-openrc

# Root path
root_path=$(pwd)

# Create kesytone db and user
mysql -u root -p$MARIADB_PASS << EOF
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';
EOF

echo 'Create glance user'
openstack user create --domain default --password $GLANCE_PASS glance

echo 'Adding admin role to glance'
openstack role add --project service --user glance admin

# Install glance from source
git clone git://github.com/openstack/glance
cd glance
pip install .
useradd -r -s /usr/bin/nologin glance -m -d /var/lib/glance
mkdir /var/lib/glance/images

# Populate /etc
mkdir /etc/glance
cd etc
cp glance-api.conf glance-api-paste.ini glance-registry.conf glance-registry-paste.ini /etc/glance
cd $root_path

# Configure glance

sed -i "/^\[database\]/a connection = mysql+pymysql://glance:$GLANCE_DBPASS@$HOSTNAME/glance" /etc/glance/glance-api.conf
sed -i "/^\[keystone_authtoken\]/a password = $GLANCE_PASS" /etc/glance/glance-api.conf
sed -i "/^\[keystone_authtoken\]/a username = glance" /etc/glance/glance-api.conf
sed -i "/^\[keystone_authtoken\]/a project_name = service" /etc/glance/glance-api.conf
sed -i "/^\[keystone_authtoken\]/a user_domain_name = default" /etc/glance/glance-api.conf
sed -i "/^\[keystone_authtoken\]/a project_domain_name = default" /etc/glance/glance-api.conf
sed -i "/^\[keystone_authtoken\]/a auth_type = password" /etc/glance/glance-api.conf
sed -i "/^\[keystone_authtoken\]/a memcached_servers = $HOSTNAME:11211" /etc/glance/glance-api.conf
sed -i "/^\[keystone_authtoken\]/a auth_url = http://$HOSTNAME:35357" /etc/glance/glance-api.conf
sed -i "/^\[keystone_authtoken\]/a auth_url = http://$HOSTNAME:5000" /etc/glance/glance-api.conf
sed -i "/^\[paste_deploy\]/a flavor = keystone" /etc/glance/glance-api.conf
sed -i "/^\[glance_store\]/a filesystem_store_datadir = /var/lib/glance/images/" /etc/glance/glance-api.conf
sed -i "/^\[glance_store\]/a default_store = file" /etc/glance/glance-api.conf
sed -i "/^\[glance_store\]/a stores = file,http" /etc/glance/glance-api.conf

sed -i "/^\[database\]/a connection = mysql+pymysql://glance:$GLANCE_DBPASS@$HOSTNAME/glance" /etc/glance/glance-registry.conf
sed -i "/^\[keystone_authtoken\]/a password = $GLANCE_PASS" /etc/glance/glance-registry.conf
sed -i "/^\[keystone_authtoken\]/a username = glance" /etc/glance/glance-registry.conf
sed -i "/^\[keystone_authtoken\]/a project_name = service" /etc/glance/glance-registry.conf
sed -i "/^\[keystone_authtoken\]/a user_domain_name = default" /etc/glance/glance-registry.conf
sed -i "/^\[keystone_authtoken\]/a project_domain_name = default" /etc/glance/glance-registry.conf
sed -i "/^\[keystone_authtoken\]/a auth_type = password" /etc/glance/glance-registry.conf
sed -i "/^\[keystone_authtoken\]/a memcached_servers = $HOSTNAME:11211" /etc/glance/glance-registry.conf
sed -i "/^\[keystone_authtoken\]/a auth_url = http://$HOSTNAME:35357" /etc/glance/glance-registry.conf
sed -i "/^\[keystone_authtoken\]/a auth_url = http://$HOSTNAME:5000" /etc/glance/glance-registry.conf
sed -i "/^\[paste_deploy\]/a flavor = keystone" /etc/glance/glance-registry.conf

su -s /bin/sh -c "glance-manage db_sync" glance

# Start glance
cp glance-*.service /usr/lib/systemd/system/
systemctl enable glance-api.service glance-registry.service
systemctl start glance-api.service glance-registry.service

# Crete service and endpoints
echo 'Create glance service'
openstack service create --name glance --description "OpenStack Image" image

echo 'Create public endpoint'
openstack endpoint create --region RegionOne image public http://$HOSTNAME:9292

echo 'Create internal endpoint'
openstack endpoint create --region RegionOne image internal http://$HOSTNAME:9292

echo 'Create admin endpoint'
openstack endpoint create --region RegionOne image admin http://$HOSTNAME:9292
