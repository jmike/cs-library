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

FW_CHAIN='Chuck_Norris' #spaces not valid here
# Chuck Norris has a website, is called the internet :)

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
   iptables --new-chain $FW_CHAIN #create new chain in "filter" table
   iptables --append INPUT --jump $FW_CHAIN #handle traffic which is entering our system (INPUT)
   iptables --append FORWARD --jump $FW_CHAIN #handle traffic which is being routed between two network interfaces on our firewall (FORWARD)
   iptables --append $FW_CHAIN --protocol icmp --icmp-type 255 --jump ACCEPT
   iptables --append $FW_CHAIN --match state --state ESTABLISHED,RELATED --jump ACCEPT
   iptables --append $FW_CHAIN --jump REJECT --reject-with icmp-host-prohibited
   # Save + restart:
   service iptables save
   service iptables restart
}

# Returns 1 if the specified port is valid, 0 if not.
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

# Allows incoming traffic to the specified port(s) of the supplied network protocol.
# $1 network protocol, either "tcp" or "udp" {REQUIRED}
# $+ port number(s) (0-65535) {REQUIRED}
function allow {
   local protocol="$1"
   shift #ignore first parameter, which represents protocol
   # Make sure protocol is specified:
   if [ -z $protocol ] ; then
      echo "Network protocol must be specified. Availiable options: tcp, udp."
      return 0 #exit
   fi
   # Make sure protocol is valid:
   if [ $protocol != "udp" -a $protocol != "tcp" ] ; then
      echo "Invalid network protocol \"$protocol\". Availiable options: tcp, udp."
      return 0 #exit
   fi
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
   iptables --delete $FW_CHAIN --jump REJECT --reject-with icmp-host-prohibited
   for port in "$@"; do
      iptables --append $FW_CHAIN --match state --state NEW --match $protocol --protocol $protocol --destination-port $port --jump ACCEPT
   done
   iptables --append $FW_CHAIN --jump REJECT --reject-with icmp-host-prohibited
   # Save + restart:
   service iptables save
   service iptables restart
}

# Denies incoming traffic to the specified port(s) of the supplied network protocol.
# $1 network protocol, either "tcp" or "udp" {REQUIRED}
# $+ port number(s) (0-65535) {REQUIRED}
function deny {
   local protocol="$1"
   shift #ignore first parameter, which represents protocol
   # Make sure protocol is specified:
   if [ -z $protocol ] ; then
      echo "Network protocol must be specified. Availiable options: tcp, udp."
      return 0 #exit
   fi
   # Make sure protocol is valid:
   if [ $protocol != "udp" -a $protocol != "tcp" ] ; then
      echo "Invalid network protocol \"$protocol\". Availiable options: tcp, udp."
      return 0 #exit
   fi
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
   iptables --delete $FW_CHAIN --match state --state NEW --match $protocol --protocol $protocol --destination-port $port --jump ACCEPT
   # Save + restart:
   service iptables save
   service iptables restart
}
