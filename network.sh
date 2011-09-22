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

# Returns the IP address assigned to the specified interface.
# $1 the name of the interface, 'eth0' by default. {OPTIONAL}
function network.get_ip {
   local ni=${1-'eth0'}
   echo $(ifconfig $ni | awk -F: '/inet addr:/ { print $2 }' | awk '{ print $1 }')
   return 0 #done
}

# Returns the reverse DNS hostname of the specified IP address.
# $1 the IP address, i.e. '192.1.1.5'. Defaults to the IP address of eth0 interface. {OPTIONAL}
function network.get_rdns {
   local ip_address=${1-$(network.get_ip)}
   # Make sure ip address is specified:
   if [ -z $ip_address ] ; then #ip address not specified
      echo "IP address must be specified."
      return 1 #exit
   fi
   # Return reverse DNS hostname:
   if [ ! -e /usr/bin/host ] ; then
      yum -y install bind-utils > /dev/null #silently install bind-utils
   fi
   echo $(host $ip_address | awk '/pointer/ {print $5}' | sed 's/\.$//')
   return 0 #done
} 

# Sets hostname to the specified value.
# $1 the FQDN hostname, i.e. 'node.cloudedsunday.com' {REQUIRED}
function network.set_hostname {
   local name="$1"
   # Make sure hostname is specified:
   if [ -z $name ] ; then #hostname not specified
      echo "Hostname must be specified."
      return 1 #exit
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
   if grep -q "^$(network.get_ip)" /etc/hosts ; then #hostname already set
      sed -i -e "s|^\($(network.get_ip)\).*$|\1 $(network.get_rdns) $name|" /etc/hosts #replace hostname
   else #hostname not set
      echo -n \
"127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4
::1 localhost localhost.localdomain localhost6 localhost6.localdomain6
$(network.get_ip) $(network.get_rdns) $name
" > /etc/hosts #set hostname
   fi
   return 0 #done
}
 
# Sets the public IP interface.
# This is the main IP address that will be used for most outbound connections. IP address, netmask and gateway must be specified.
# $1 the IP address. {REQUIRED}
# $2 the netmask. {REQUIRED}
# $3 the gateway. {REQUIRED}
function network.set_public_ip {
   local ip_address="$1"
   local netmask="$2"
   local gateway="$3"
   # Make sure ip address is specified:
   if [ -z $ip_address ] ; then #ip address not specified
      echo "Public interface's IP address must be specified."
      return 1 #exit
   fi
   # Make sure netmask is specified:
   if [ -z $netmask ] ; then #netmask not specified
      echo "Public interface's netmask must be specified."
      return 1 #exit
   fi
   # Make sure gateway is specified:
   if [ -z $gateway ] ; then #gateway not specified
      echo "Public interface's gateway must be specified."
      return 1 #exit
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
   return 0 #done
}

# Sets the private IP interface.
# Private IPs have no gateway (they are not publicly routable), thus only IP address and netmask need be specified.
# $1 the IP address. {REQUIRED}
# $2 the netmask.  {REQUIRED}
function network.set_private_ip {
   local ip_address="$1"
   local netmask="$2"
   # Make sure ip address is specified:
   if [ -z $ip_address ] ; then #ip address not specified
      echo "Private interface's IP address must be specified."
      return 1 #exit
   fi
   # Make sure netmask is specified:
   if [ -z $netmask ] ; then #netmask not specified
      echo "Private interface's netmask must be specified."
      return 1 #exit
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
   return 0 #done
}

# Sets the local domain name.
# $1 the name of the local domain, i.e. 'members.linode.com'. {REQUIRED}
function network.set_domain {
   local name="$1"
   # Make sure name is specified:
   if [ -z $name ] ; then
      echo "Local domain name must be specified."
      return 1 #exit
   fi
   # Set domain:
   sed -i \
-e "/^domain/d" \
-e "$ a \
domain $name" \
/etc/resolv.conf
   return 0 #done
}

# Sets the search list for hostnames lookup.
# Usually this is the same as the local domain.
# $1 the hostname of the search list, i.e. 'members.linode.com'. {REQUIRED}
function network.set_search_list {
   local name="$1"
   # Make sure name is specified:
   if [ -z $name ] ; then
      echo "Search list must be specified."
      return 1 #exit
   fi
   # Set domain:
   sed -i \
-e "/^search/d" \
-e "$ a \
search $name" \
/etc/resolv.conf
   return 0 #done
}

# Sets the nameserver(s) of the DNS resolver.
# $+ the IP address(es) of the nameserver(s) separated by space. {REQUIRED}
function network.set_resolver_ns {
   # Make sure at least one nameserver is specified:
   if [ $# -eq 0 ] ; then
      echo "At least one nameserver must be specified."
      return 1 #exit      
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
   return 0 #done
}

# Restarts the network service.
function network.restart {
   service network restart
   service network status
   return 0 #done
}

# Returns 0 if the specified port is valid, 1 if not.
# $1 port number, positive integer ranging between 0 and 65535. {REQUIRED}
function network.valid_port {
   local port="$1"
   if [[ $port =~ ^[0-9]+$ ]] ; then #port is an integer
      if [ $port -gt 65535 ] ; then #port number is invalid
         return 1
      else #port is valid
         return 0
      fi
   else #port is not an integer
      return 1
   fi
}
