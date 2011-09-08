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

# Returns the primary IP address assigned to public (eth0) interface.
function get_primary_ip {
   echo $(ifconfig eth0 | awk -F: '/inet addr:/ { print $2 }' | awk '{ print $1 }')
}

# Returns the primary IP address assigned to private (eth0:1) interface.
function get_private_primary_ip {
   echo $(ifconfig eth0:1 | awk -F: '/inet addr:/ { print $2 }' | awk '{ print $1 }')
}

# Returns the reverse DNS hostname of the specified IP address.
# $1 the IP address, i.e. 192.1.1.5 {REQUIRED}
function get_rdns {
   local ip_address="$1"
   # Make sure ip address is specified:
   if [ -z $ip_address ] ; then #ip address not specified
      echo "IP address must be specified."
      return 0 #exit
   fi
   # Return reverse DNS hostname:
   if [ ! -e /usr/bin/host ] ; then
      yum -y install bind-utils > /dev/null #silently install bind-utils
   fi
   echo $(host $ip_address | awk '/pointer/ {print $5}' | sed 's/\.$//')
} 

# Returns the reverse DNS hostname of the primary IP address.
function get_rdns_primary_ip {
   echo $(get_rdns $(get_primary_ip))
}

# Sets hostname to the specified value.
# $1 the FQDN hostname, i.e. mitsos.local.host {REQUIRED}
function set_hostname {
   local name="$1"
   # Make sure hostname is specified:
   if [ -z $name ] ; then #hostname not specified
      echo "Hostname must be specified."
      return 0 #exit
   fi
   # Set hostname:
   hostname $name
   # Set /etc/hostname:
   echo $name > /etc/hostname
   # Set /etc/sysconfig/network:
   if grep -q "^HOSTNAME=" /etc/sysconfig/network ; then #hostname already set
      sed -i -e "s|^\(HOSTNAME=\).*$|\1$name|" /etc/sysconfig/network #replace hostname
   else #hostname not set
      echo "HOSTNAME=$name" >> /etc/sysconfig/network #append hostname
   fi
   # Set /etc/hosts:
   if grep -q "^$(get_primary_ip)" /etc/hosts ; then #hostname already set
      sed -i -e "s|^\($(get_primary_ip)\).*$|\1 $(get_rdns_primary_ip) $name|" /etc/hosts #replace hostname
   else #hostname not set
      echo -n \
"127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4
::1 localhost localhost.localdomain localhost6 localhost6.localdomain6
$(get_primary_ip) $(get_rdns_primary_ip) $name
" > /etc/hosts #set hostname
   fi
}
 
# Sets the public IP interface.
# This is the main IP address that will be used for most outbound connections. IP address, netmask and gateway must be specified.
# $1 the IP address {REQUIRED}
# $2 the netmask {REQUIRED}
# $3 the gateway {REQUIRED}
function set_public_ip {
   local ip_address="$1"
   local netmask="$2"
   local gateway="$3"
   # Make sure ip address is specified:
   if [ -z $ip_address ] ; then #ip address not specified
      echo "Public interface's IP address must be specified."
      return 0 #exit
   fi
   # Make sure netmask is specified:
   if [ -z $netmask ] ; then #netmask not specified
      echo "Public interface's netmask must be specified."
      return 0 #exit
   fi
   # Make sure gateway is specified:
   if [ -z $gateway ] ; then #gateway not specified
      echo "Public interface's gateway must be specified."
      return 0 #exit
   fi
   # Set interface
   echo -n \
"# Configuration for eth0
DEVICE=eth0
BOOTPROTO=none
ONBOOT=yes #ensures that the interface will be brought up during boot
PEERDNS=no
NM_CONTROLLED=no #tells NetworkManager not to manage this interface
IPADDR=$ip_address
NETMASK=$netmask
GATEWAY=$gateway
" > /etc/sysconfig/network-scripts/ifcfg-eth0
}

# Sets the private IP interface.
# Private IPs have no gateway (they are not publicly routable), thus only IP address and netmask need be specified.
# $1 the IP address {REQUIRED}
# $2 the netmask  {REQUIRED}
function set_private_ip {
   local ip_address="$1"
   local netmask="$2"
   # Make sure ip address is specified:
   if [ -z $ip_address ] ; then #ip address not specified
      echo "Private interface's IP address must be specified."
      return 0 #exit
   fi
   # Make sure netmask is specified:
   if [ -z $netmask ] ; then #netmask not specified
      echo "Private interface's netmask must be specified."
      return 0 #exit
   fi
   # Set interface
   echo -n \
"# Configuration for eth0:1
DEVICE=eth0:1
BOOTPROTO=none
ONBOOT=yes #ensures that the interface will be brought up during boot
PEERDNS=no
NM_CONTROLLED=no #tells NetworkManager not to manage this interface
IPADDR=$ip_address
NETMASK=$netmask
" > /etc/sysconfig/network-scripts/ifcfg-eth0:1
}

# Sets the local domain name.
# $1 the name of the local domain {REQUIRED}
function set_domain {
   local name="$1"
   # Make sure name is specified:
   if [ -z $name ] ; then
      echo "Local domain name must be specified."
      return 0 #exit
   fi
   # Set domain:
   sed -i \
-e "/^domain/d" \
-e "$ a \
domain $name" \
/etc/resolv.conf
}

# Sets the search list for hostnames lookup.
# Usually this is the same as the local domain.
# $1 the hostname of the search list {REQUIRED}
function set_search_list {
   local name="$1"
   # Make sure name is specified:
   if [ -z $name ] ; then
      echo "Search list must be specified."
      return 0 #exit
   fi
   # Set domain:
   sed -i \
-e "/^search/d" \
-e "$ a \
search $name" \
/etc/resolv.conf
}

# Sets the nameserver(s) of the DNS resolver.
# $+ the IP address(es) of the nameserver(s) {REQUIRED}
function set_resolver_ns {
   # Make sure at least one nameserver is specified:
   if [ $# -eq 0 ] ; then
      echo "At least one nameserver must be specified."
      return 0 #exit      
   fi
   # Remove old nameserver(s):
   sed -i -e "/^nameserver/d" /etc/resolv.conf
   # Append new nameserver(s):
   for nameserver in "$@"; do
      echo "nameserver $nameserver" >> /etc/resolv.conf
   done
   # Set options:
   sed -i \
-e "/^options/d" \
-e "$ a \
options rotate" \
/etc/resolv.conf
}

# Restarts the network service.
function restart_network {
   service network restart
   service network status
}
