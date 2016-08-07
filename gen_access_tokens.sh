which pwgen > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
	pacman -S pwgen --noconfirm
fi
pwgen='pwgen 32 1'
cat > access_tokens << EOF
ADMIN_PASS=$($pwgen)
CEILOMETER_DBPASS=$($pwgen)
CEILOMETER_PASS=$($pwgen)
CINDER_DBPASS=$($pwgen)
CINDER_PASS=$($pwgen)
DASH_DBPASS=$($pwgen)
DEMO_PASS=$($pwgen)
GLANCE_DBPASS=$($pwgen)
GLANCE_PASS=$($pwgen)
HEAT_DBPASS=$($pwgen)
HEAT_DOMAIN_PASS=$($pwgen)
HEAT_PASS=$($pwgen)
KEYSTONE_DBPASS=$($pwgen)
NEUTRON_DBPASS=$($pwgen)
NEUTRON_PASS=$($pwgen)
NOVA_DBPASS=$($pwgen)
NOVA_PASS=$($pwgen)
RABBIT_PASS=$($pwgen)
SWIFT_PASS=$($pwgen)
MARIADB_PASS=$($pwgen)
EOF

chmod 400 access_tokens
