#!/bin/env python2
import ConfigParser
import netifaces

provider_interface_name = [interface for interface in netifaces.interfaces() if interface.startswith('en')][0]
overlay_interface_ip_address = netifaces.ifaddresses(provider_interface_name)[netifaces.AF_INET][0]['addr']

lba = ConfigParser.RawConfigParser()

lba.add_section('linux_bridge')
lba.set('linux_bridge', 'physical_interface_mappings', 'provider:' + provider_interface_name)

lba.add_section('vxlan')
lba.set('vxlan', 'enable_vxlan', True)
lba.set('vxlan', 'local_ip', overlay_interface_ip_address)
lba.set('vxlan', '12_population', True)

lba.add_section('securitygroup')
lba.set('securitygroup', 'enable_security_group', True)
lba.set('securitygroup', 'firewall_driver', 'neutron.agent.linux.iptables_firewall.IptablesFirewallDriver')

with open('/etc/neutron/plugins/ml2/linuxbridge_agent.ini', 'wb') as configfile:
        lba.write(configfile)
