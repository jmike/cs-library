#!/bin/bash
#
# Copyright 2011 Alexandros Iosifidis, Dimitrios Michalakos
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

source firewall.sh

# Sets a basic hardened linux node, configured and ready for production.
# $1 Hostname
# $2 Public IP
# $3 Public NetMask
# $4 Public Gateway
# $5 Private IP
# $6 Private NetMask
# $7 Username
# $8 Password
function set_basic_node {
   # Secure the system:
   useradd $7
   echo "$8" | passwd "$7" --stdin
   set_superuser $7
   set_firewall
   set_sshd
   install_fail2ban
   enable_fail2ban_jail SSH
   # Configure networking:
   set_timezone
   set_hostname $1
   set_public_ip $2 $3 $4
   set_private_ip $5 $6
   restart_network
   set_dns_resolver
   restart_network #yet again
   # Update and install extras:
   update
   install_extras
}
