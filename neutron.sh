# Include access tokens
. admin-openrc

# Root path
root_path=$(pwd)

# Create kesytone db and user
mysql -u root -p$MARIADB_PASS << EOF
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS';
EOF

# Install nova from source
pacman -S sudo libvirt-python dnsmasq ebtables dmidecode qemu --noconfirm

git clone git://github.com/openstack/neutron
cd neutron
pip2 install .
useradd -r -s /usr/bin/nologin neutron -m -d /var/lib/neutron

# Populate /etc
oslo-config-generator --config-file etc/oslo-config-generator/neutron.conf
mkdir /etc/neutron
cd etc
cp -r policy.json rootwrap.conf api-paste.ini neutron/rootwrap.d neutron/plugins  /etc/neutron
cp neutron.conf.sample /etc/neutron/neutron.conf
cd $root_path

# Configure nova

sed -i "/^\[DEFAULT\]/a allow_overlapping_ips = True" /etc/neutron/neutron.conf
sed -i "/^\[DEFAULT\]/a service_plugins = router" /etc/neutron/neutron.conf
sed -i "/^\[DEFAULT\]/a core_plugin = ml2" /etc/neutron/neutron.conf
sed -i "/^\[database\]/a connection = mysql+pymysql://neutron:$NEUTRON_DBPASS@$HOSTNAME/neutron" /etc/neutron/neutron.conf

# Add rabbitmq

sed -i "/^\[DEFAULT\]/a rpc_backend = rabbit" /etc/neutron/neutron.conf
sed -i "/^\[oslo_messaging_rabbit\]/a rabbit_host = $HOSTNAME" /etc/neutron/neutron.conf
sed -i "/^\[oslo_messaging_rabbit\]/a rabbit_userid = openstack" /etc/neutron/neutron.conf
sed -i "/^\[oslo_messaging_rabbit\]/a rabbit_password = $RABBIT_PASS" /etc/neutron/neutron.conf

# Add keystone

sed -i "/^\[DEFAULT\]/a auth_strategy = keystone" /etc/neutron/neutron.conf
sed -i "/^\[keystone_authtoken\]/a password = $NEUTRON_PASS" /etc/neutron/neutron.conf
sed -i "/^\[keystone_authtoken\]/a username = neutron" /etc/neutron/neutron.conf
sed -i "/^\[keystone_authtoken\]/a project_name = service" /etc/neutron/neutron.conf
sed -i "/^\[keystone_authtoken\]/a user_domain_name = default" /etc/neutron/neutron.conf
sed -i "/^\[keystone_authtoken\]/a project_domain_name = default" /etc/neutron/neutron.conf
sed -i "/^\[keystone_authtoken\]/a auth_type = password" /etc/neutron/neutron.conf
sed -i "/^\[keystone_authtoken\]/a memcached_servers = $HOSTNAME:11211" /etc/neutron/neutron.conf
sed -i "/^\[keystone_authtoken\]/a auth_url = http://$HOSTNAME:35357" /etc/neutron/neutron.conf
sed -i "/^\[keystone_authtoken\]/a auth_url = http://$HOSTNAME:5000" /etc/neutron/neutron.conf

# Notify compute

sed -i "/^\[DEFAULT\]/a notify_nova_on_port_status_changes = True" /etc/neutron/neutron.conf
sed -i "/^\[DEFAULT\]/a notify_nova_on_port_data_changes = True" /etc/neutron/neutron.conf
sed -i "/^\[nova\]/a password = $NOVA_PASS" /etc/neutron/neutron.conf
sed -i "/^\[nova\]/a username = nova" /etc/neutron/neutron.conf
sed -i "/^\[nova\]/a project_name = service" /etc/neutron/neutron.conf
sed -i "/^\[nova\]/a region_name = RegionOne" /etc/neutron/neutron.conf
sed -i "/^\[nova\]/a user_domain_name = default" /etc/neutron/neutron.conf
sed -i "/^\[nova\]/a project_domain_name = default" /etc/neutron/neutron.conf
sed -i "/^\[nova\]/a auth_type = password" /etc/neutron/neutron.conf
sed -i "/^\[nova\]/a auth_url = http://$HOSTNAME:35357" /etc/neutron/neutron.conf

# Modular Layer 2

cat > /etc/neutron/plugins/ml2/ml2_conf.ini << EOF
[ml2]
type_drivers = flat,vlan,vxlan
tenant_network_types = vxlan
mechanism_drivers = linuxbridge,l2population
extension_drivers = port_security

[ml2_type_flat]
flat_networks = provider

[ml2_type_vxlan]
vni_ranges = 1:1000

[securitygroup]
enable_ipset = True
EOF

# Linux bridge agent

python2 linuxbridge_config_generator.py

# Modular Layer 3

cat > /etc/neutron/l3_agent.ini << EOF
[DEFAULT]
interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver
external_network_bridge =
EOF

cat > /etc/neutron/dhcp_agent.ini << EOF
[DEFAULT]
interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = True
EOF

cat > /etc/neutron/metadata_agent.ini << EOF
[DEFAULT]
nova_metadata_ip = controller
metadata_proxy_shared_secret = $METADATA_SECRET
EOF

cat >> /etc/nova/nova.conf << EOF
url = http://controller:9696
auth_url = http://controller:35357
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = $NEUTRON_PASS

service_metadata_proxy = True
metadata_proxy_shared_secret = $METADATA_SECRET
EOF

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
	  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

echo 'Create nova user'
openstack user create --domain default --password $NEUTRON_PASS neutron

echo 'Adding admin role to nova'
openstack role add --project service --user neutron admin

echo 'Create compute servie'
openstack service create --name neutron \
	  --description "OpenStack Networking" network

echo 'Adding public endpoint'
openstack endpoint create --region RegionOne \
	  network public http://$HOSTNAME:9696

echo 'Adding internal endpoint'
openstack endpoint create --region RegionOne \
	  network internal http://$HOSTNAME:9696

echo 'Adding admin endpoint'
openstack endpoint create --region RegionOne \
	  network admin http://$HOSTNAME:9696

# Starting services
systemctl restart nova-api.service
