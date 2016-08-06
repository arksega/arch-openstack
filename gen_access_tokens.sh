which pwgen > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
	pacman -S pwgen --noconfirm
fi
cat > access_tokens << EOF
ADMIN_PASS=$(pwgen 12 1)
CEILOMETER_DBPASS=$(pwgen 12 1)
CEILOMETER_PASS=$(pwgen 12 1)
CINDER_DBPASS=$(pwgen 12 1)
CINDER_PASS=$(pwgen 12 1)
DASH_DBPASS=$(pwgen 12 1)
DEMO_PASS=$(pwgen 12 1)
GLANCE_DBPASS=$(pwgen 12 1)
GLANCE_PASS=$(pwgen 12 1)
HEAT_DBPASS=$(pwgen 12 1)
HEAT_DOMAIN_PASS=$(pwgen 12 1)
HEAT_PASS=$(pwgen 12 1)
KEYSTONE_DBPASS=$(pwgen 12 1)
NEUTRON_DBPASS=$(pwgen 12 1)
NEUTRON_PASS=$(pwgen 12 1)
NOVA_DBPASS=$(pwgen 12 1)
NOVA_PASS=$(pwgen 12 1)
RABBIT_PASS=$(pwgen 12 1)
SWIFT_PASS=$(pwgen 12 1)
EOF

chmod 400 access_tokens
