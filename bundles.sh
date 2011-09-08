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

source system.sh
source network.sh
source firewall.sh
source fail2ban.sh

# Sets a basic hardened linux node, configured and ready for production.
# $1 Hostname {REQUIRED}
# $2 Public IP address {REQUIRED}
# $3 Public netmask {REQUIRED}
# $4 Public gateway {REQUIRED}
# $5 Private IP address {REQUIRED}
# $6 Private netmask {REQUIRED}
# $7 SSH port {REQUIRED}
# $8 Admin username, i.e. "maria" {REQUIRED}
# $9 Admin password {REQUIRED}
function set_basic_node {
   # Make sure required parameters are specified, no more, no less:
   if [ ! $# -eq 9 ] ; then
      echo "Errors found in supplied parameters. Plese refer to function's documentation."
      return 0 #exit
   fi
   # Load dependencies:
   source ssh.sh $7
   # Secure the system:
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
   # Update & install extras:
   update
   install_extras
   # Create admin account:
   if ! grep -iq "^$8" /etc/passwd ; then #user does not exist
      useradd $8
   fi
   echo "$9" | passwd "$8" --stdin
   set_superuser $8
   # Reboot system:
   reboot
}










