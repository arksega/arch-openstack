# Include access tokens
. admin-openrc

# Root path
root_path=$(pwd)

# Create kesytone db and user
mysql -u root -p$MARIADB_PASS << EOF
CREATE DATABASE nova_api;
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
EOF

# Install nova from source
pacman -S sudo --noconfirm
git clone git://github.com/openstack/nova
cd nova
pip2 install .
useradd -r -s /usr/bin/nologin nova -m -d /var/lib/nova
mkdir /var/lib/nova/images
mkdir /usr/lib/python2.7/site-packages/keys

# Populate /etc
oslo-config-generator --config-file etc/nova/nova-config-generator.conf
mkdir /etc/nova
cd etc/nova
cp -r rootwrap.d rootwrap.conf api-paste.ini /etc/nova
cp nova.conf.sample /etc/nova/nova.conf
cd $root_path

# Configure nova

sed -i "/^\[DEFAULT\]/a enabled_api = osapi_compute,metadata" /etc/nova/nova.conf
sed -i "/^\[DEFAULT\]/a my_api = 192.168.100.129" /etc/nova/nova.conf
sed -i "/^\[DEFAULT\]/a use_neutron = True" /etc/nova/nova.conf
sed -i "/^\[DEFAULT\]/a firewall_driver = nova.virt.firewall.NoopFirewallDriver" /etc/nova/nova.conf
sed -i "/^\[database\]/a \[api_database\]" /etc/nova/nova.conf
sed -i "/^\[api_database\]/a \[glance\]" /etc/nova/nova.conf
sed -i "/^\[api_database\]/a  " /etc/nova/nova.conf
sed -i "/^\[glance\]/a  " /etc/nova/nova.conf
sed -i "/^\[glance\]/a api_servers = http://$HOSTNAME:9292" /etc/nova/nova.conf
sed -i "/^\[api_database\]/a connection = mysql+pymysql://nova:$NOVA_DBPASS@$HOSTNAME/nova_api" /etc/nova/nova.conf
sed -i "/^\[database\]/a connection = mysql+pymysql://nova:$NOVA_DBPASS@$HOSTNAME/nova" /etc/nova/nova.conf
sed -i "/^\[vnc\]/a vncserver_listen = $my_ip" /etc/nova/nova.conf
sed -i "/^\[vnc\]/a vncserver_proxyclient_address = $my_ip" /etc/nova/nova.conf
sed -i "/^\[glance\]/a api_servers = http://$HOSTNAME:9292" /etc/nova/nova.conf
sed -i "/^\[oslo_concurrency\]/a lock_path = /var/lib/nova/tmp" /etc/nova/nova.conf

# Configure sudoers

cat 'nova ALL = (root) NOPASSWD: /usr/bin/nova-rootwrap /etc/nova/rootwrap.conf *' >> /etc/sudoers
cat 'Defaults requiretty' >> /etc/sudoers

# Add rabbitmq

sed -i "/^\[DEFAULT\]/a rpc_backend = rabbit" /etc/nova/nova.conf
sed -i "/^\[oslo_messaging_rabbit\]/a rabbit_host = $HOSTNAME" /etc/nova/nova.conf
sed -i "/^\[oslo_messaging_rabbit\]/a rabbit_userid = openstack" /etc/nova/nova.conf
sed -i "/^\[oslo_messaging_rabbit\]/a rabbit_password = $RABBIT_PASS" /etc/nova/nova.conf

# Add keystone

sed -i "/^\[DEFAULT\]/a auth_strategy = keystone" /etc/nova/nova.conf
sed -i "/^\[keystone_authtoken\]/a password = $NOVA_PASS" /etc/nova/nova.conf
sed -i "/^\[keystone_authtoken\]/a username = nova" /etc/nova/nova.conf
sed -i "/^\[keystone_authtoken\]/a project_name = service" /etc/nova/nova.conf
sed -i "/^\[keystone_authtoken\]/a user_domain_name = default" /etc/nova/nova.conf
sed -i "/^\[keystone_authtoken\]/a project_domain_name = default" /etc/nova/nova.conf
sed -i "/^\[keystone_authtoken\]/a auth_type = password" /etc/nova/nova.conf
sed -i "/^\[keystone_authtoken\]/a memcached_servers = $HOSTNAME:11211" /etc/nova/nova.conf
sed -i "/^\[keystone_authtoken\]/a auth_url = http://$HOSTNAME:35357" /etc/nova/nova.conf
sed -i "/^\[keystone_authtoken\]/a auth_url = http://$HOSTNAME:5000" /etc/nova/nova.conf


su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage db sync" nova

echo 'Create nova user'
openstack user create --domain default --password $NOVA_PASS nova

echo 'Adding admin role to nova'
openstack role add --project service --user nova admin

echo 'Create compute servie'
openstack service create --name nova \
	  --description "OpenStack Compute" compute

echo 'Adding public endpoint'
openstack endpoint create --region RegionOne \
	  compute public http://$HOSTNAME:8774/v2.1/%\(tenant_id\)s

echo 'Adding internal endpoint'
openstack endpoint create --region RegionOne \
	  compute internal http://$HOSTNAME:8774/v2.1/%\(tenant_id\)s

echo 'Adding admin endpoint'
openstack endpoint create --region RegionOne \
	  compute admin http://$HOSTNAME:8774/v2.1/%\(tenant_id\)s


