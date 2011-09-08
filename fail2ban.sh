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

FAIL2BAN_URI='http://sourceforge.net/projects/fail2ban/files/fail2ban-stable/fail2ban-0.8.4/fail2ban-0.8.4.tar.bz2/download'
FAIL2BAN_HOME_DIR='/opt/fail2ban'
FAIL2BAN_CONF_DIR='/etc/fail2ban'
FAIL2BAN_LOG_DIR='/var/log/fail2ban'
FAIL2BAN_STATE_DIR='/var/run/fail2ban'

# Installs fail2ban to block automated attempts to compromise the system.
# Please refer to http://www.fail2ban.org for further study.
function install_fail2ban {
   # Fail2Ban runs under root account.
   # Create directories & set appropriate permissions:
   mkdir -m u=rwx,g=rx,o=rx $FAIL2BAN_HOME_DIR
   mkdir -m u=rwx,g=,o= $FAIL2BAN_CONF_DIR
   mkdir -m u=rwx,g=,o= $FAIL2BAN_LOG_DIR
   mkdir -m u=rwx,g=,o= $FAIL2BAN_STATE_DIR
   # Donwload, compile & install files:
   cd ~
   wget $FAIL2BAN_URI #obtain source code
   tar -jxf fail2ban*.tar.bz2 #unpack bzip2 archive
   cd fail2ban*
   sed -i -e "s|^\(install-purelib\)\(\s\?=\s\?\)\(.*\)$|\1=$FAIL2BAN_HOME_DIR|" ./setup.cfg #replace home path in setup config file
   ./setup.py install #install
   # Binaries are always installed in "/usr/bin", irrespective of the home path.
   sed -i -e "s|/usr/share/fail2ban|$FAIL2BAN_HOME_DIR|" /usr/bin/fail2ban* #replace home path in binaries
   # Configure:
   sed -i -e "s|^\(loglevel\)\(\s\?=\s\?\)\(.*\)$|\1 = 3|" $FAIL2BAN_CONF_DIR/fail2ban.conf #log messages of level INFO (or higher)
   sed -i -e "s|^\(logtarget\)\(\s\?=\s\?\)\(.*\)$|\1 = $FAIL2BAN_LOG_DIR/fail2ban.log|" $FAIL2BAN_CONF_DIR/fail2ban.conf #set log target
   sed -i -e "s|^\(socket\)\(\s\?=\s\?\)\(.*\)$|\1 = $FAIL2BAN_STATE_DIR/fail2ban.sock|" $FAIL2BAN_CONF_DIR/fail2ban.conf #set sock file
   chmod u=rw,g=r,o= $FAIL2BAN_CONF_DIR/fail2ban.conf
   sed -i -e "s|^\(maxretry\)\(\s\?=\s\?\)\(.*\)$|\1 = 3|" $FAIL2BAN_CONF_DIR/jail.conf #after 3 failed attemts user gets banned
   sed -i -e "s|^\(findtime\)\(\s\?=\s\?\)\(.*\)$|\1 = 3660|" $FAIL2BAN_CONF_DIR/jail.conf #failed attemts must occur within 1 hour and 60 seconds
   sed -i -e "s|^\(bantime\)\(\s\?=\s\?\)\(.*\)$|\1 = 7200|" $FAIL2BAN_CONF_DIR/jail.conf #user remains banned for 2 hours!
   chmod u=rw,g=r,o= $FAIL2BAN_CONF_DIR/jail.conf
   # Set logs:
   touch $FAIL2BAN_LOG_DIR/fail2ban.log
   chmod u=rw,g=,o= $FAIL2BAN_LOG_DIR/fail2ban.log
   # Integrate into logrotate:
   echo -n \
"$FAIL2BAN_LOG_DIR/fail2ban.log {
   daily
   rotate 40
   extension log
   dateext
   dateformat %Y%m%d
   compress
   delaycompress
   missingok
   noolddir
   create 0644 root root
   postrotate
      /usr/local/bin/fail2ban-client reload 1>/dev/null || true
   endscript
}" > /etc/logrotate.d/fail2ban
   chmod u=rw,g=r,o=r /etc/logrotate.d/fail2ban
   # Set daemon:
   cd ~/fail2ban*
   /bin/cp -rf files/redhat-initd /etc/init.d/fail2ban #copy init.d script
   chmod u=rwx,g=rx,o= /etc/init.d/fail2ban #make executable
   chkconfig --add fail2ban
   chkconfig --level 35 fail2ban on
   service fail2ban start
   # Collect garbage:
   cd ~
   rm -rf fail2ban*
}

# Enables a fail2ban jail of the specified type.
# $1 the type of the jail, "SSH" by default. {OPTIONAL}
function enable_fail2ban_jail {
   local type=${1-"SSH"}
   case $type in
      'SSH')
         sed -i -e "/^\[ssh-iptables\]$/,/^\[.*\]$/ s|^\(enabled\)\(\s*=\s*\)\(.*\)$|\1 = true|g" $FAIL2BAN_CONF_DIR/jail.conf #enable jail
         sed -i -e "/^\[ssh-iptables\]$/,/^\[.*\]$/ s|port\s*=\s*ssh|port=58224|g" $FAIL2BAN_CONF_DIR/jail.conf #set running port
         sed -i -e "/^\[ssh-iptables\]$/,/^\[.*\]$/ s|^\(maxretry\)\(\s*=\s*\)\(.*\)$|\1 = 3|g" $FAIL2BAN_CONF_DIR/jail.conf #after 3 failed login attemps, user gets banned
         sed -i -e "/^\[ssh-iptables\]$/,/^\[.*\]$/ s|^\s*sendmail-whois\[.*\]$||g" $FAIL2BAN_CONF_DIR/jail.conf #disable email notification
         sed -i -e "/^\[ssh-iptables\]$/,/^\[.*\]$/ s|^\(logpath\)\(\s*=\s*\)\(.*\)$|\1 = /var/log/secure|g" $FAIL2BAN_CONF_DIR/jail.conf # set ssh log path
         ;;
      *)
         echo "Unknown jail type. Available options: SSH."
         return 0 #exit
         ;;
   esac
   service fail2ban restart
}

# Unblocks a host that was banned by fail2ban.
# $1 IP address or hostname of the client. {REQUIRED}
# $2 the type of the jail that user will be unblocked from, "SSH" by default. {OPTIONAL}
function remove_banned_host {
   local host="$1"
   local type=${1-'SSH'}
   # Make sure host is specified:
   if [ -z $host ] ; then #host not specified
      echo "IP address or hostname must be specified."
      return 0 #exit
   fi
   # Unblock host:
   case $type in
      'SSH')
         iptables --delete fail2ban-SSH --source $host --jump DROP
         ;;
      *)
         echo "Unknown jail type. Available options: SSH."
         return 0 #exit
         ;;
   esac
}
