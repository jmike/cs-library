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

# Initializes iptables with basic firewall rules.
function set_firewall {
   # Configure:
   sed -i -e 's|^\(IPTABLES_MODULES=\)\(.*\)$|\1""|' /etc/sysconfig/iptables-config #disable all modules
   sed -i -e 's|^\(IPTABLES_MODULES_UNLOAD=\)\(.*\)$|\1"no"|' /etc/sysconfig/iptables-config
   chmod u=rw,g=,o= /etc/sysconfig/iptables-config
   # Set daemon:
   # Linode kernels contain an extra policy chain, named "security", which causes iptables to fail on start-up.
   if uname -r | grep -iq "linode" ; then #kernel requires iptables patching
      cd ~
      wget http://epoxie.net/12023.txt #obtain patch
      cat 12023.txt | tr -d '\r' > /etc/init.d/iptables
      rm -f 12023.txt #collect garbage
   fi
   chmod u=rwx,g=rx,o= /etc/init.d/iptables
   chkconfig --add iptables
   chkconfig --level 35 iptables on #survive system reboot
   # Set basic rules & policies:
   iptables --flush #delete all predefined rules in "filter" table
   iptables --table nat --flush #delete all predefined rules in "nat" table
   iptables --table mangle --flush #delete all predefined rules in "mangle" table
   iptables --delete-chain #delete all user-defined chains in "filter" table
   iptables --policy OUTPUT ACCEPT #set new policy: allow traffic which originated from our system (OUTPUT)
   iptables --new-chain Chuck_Norris #create new chain in "filter" table
   iptables --append INPUT --jump Chuck_Norris #handle traffic which is entering our system (INPUT)
   iptables --append FORWARD --jump Chuck_Norris #handle traffic which is being routed between two network interfaces on our firewall (FORWARD)
   iptables --append Chuck_Norris --protocol icmp --icmp-type 255 --jump ACCEPT #Chuck Norris allows ping
   iptables --append Chuck_Norris --match state --state ESTABLISHED,RELATED --jump ACCEPT #Chuck Norris allows connections that are already established
   iptables --append Chuck_Norris --jump REJECT --reject-with icmp-host-prohibited #Chuck Norris denies everything else
   # Save + restart:
   service iptables save
   service iptables restart
}

# Returns 1 if the specified port number is valid, 0 if not.
# $1 port number (0-65535) {REQUIRED}
function valid_port {
   local port="$1"
   if [[ $port =~ ^[0-9]+$ ]] ; then #port is an integer
      if [ $port -gt 65535 ] ; then #port number is invalid
         return 0
      else #port is valid
         return 1
      fi
   else #port is not an integer
      return 0
   fi
}

# Allows incoming traffic to the specified TCP port(s).
# $+ port number(s) (0-65535) {REQUIRED}
function allow_tcp {
   # Make sure at least one port is specified:
   if [ $# -eq 0 ] ; then
      echo "At least one port number must be specified."
      return 0 #exit      
   fi
   # Make sure the specified port(s) are valid:
   for port in "$@"; do
      if valid_port $port == 0 ; then
         echo "Invalid port $port. Please specify a number between 0 and 65535."
         return 0 #exit         
      fi     
   done
   # Append rule to iptables:
   iptables --delete Chuck_Norris --jump REJECT --reject-with icmp-host-prohibited
   for port in "$@"; do
      iptables --append Chuck_Norris --match state --state NEW --match tcp --protocol tcp --destination-port $port --jump ACCEPT
   done
   iptables --append Chuck_Norris --jump REJECT --reject-with icmp-host-prohibited #Chuck Norris denies everything else
   # Save + restart:
   service iptables save
   service iptables restart
}

# Denies incoming traffic to the specified TCP port(s).
# $+ port number(s) (0-65535) {REQUIRED}
function deny_tcp {
   # Make sure at least one port is specified:
   if [ $# -eq 0 ] ; then
      echo "At least one port number must be specified."
      return 0 #exit      
   fi
   # Make sure the specified port(s) are valid:
   for port in "$@"; do
      if valid_port $port == 0 ; then
         echo "Invalid port $port. Please specify a number between 0 and 65535."
         return 0 #exit         
      fi    
   done
   # Delete rule from iptables:
   iptables --delete Chuck_Norris --match state --state NEW --match tcp --protocol tcp --destination-port $port --jump ACCEPT
   # Save + restart:
   service iptables save
   service iptables restart
}

# Allows incoming traffic to the specified UDP port(s).
# $+ port number(s) (0-65535) {REQUIRED}
function allow_udp {
   # Make sure at least one port is specified:
   if [ $# -eq 0 ] ; then
      echo "At least one port number must be specified."
      return 0 #exit      
   fi
   # Make sure the specified port(s) are valid:
   for port in "$@"; do
      if valid_port $port == 0 ; then
         echo "Invalid port $port. Please specify a number between 0 and 65535."
         return 0 #exit         
      fi    
   done
   # Append rule to iptables:
   iptables --delete Chuck_Norris --jump REJECT --reject-with icmp-host-prohibited
   for port in "$@"; do
      iptables --append Chuck_Norris --match state --state NEW --match udp --protocol udp --destination-port $port --jump ACCEPT
   done
   iptables --append Chuck_Norris --jump REJECT --reject-with icmp-host-prohibited #Chuck Norris denies everything else
   # Save + restart:
   service iptables save
   service iptables restart
}
