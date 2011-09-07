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

MYSQL_PROXY_URI="http://dev.mysql.com/get/Downloads/MySQL-Proxy/mysql-proxy-0.8.2-linux-glibc2.3-x86-64bit.tar.gz/from/http://mirrors.dedipower.com/www.mysql.com/"
MYSQL_PROXY_USER="mysql-proxy"
MYSQL_PROXY_GROUP="mysql-proxy"
MYSQL_PROXY_HOME_DIR="/opt/mysql-proxy"
MYSQL_PROXY_LOG_DIR="/var/log/mysql-proxy"
MYSQL_PROXY_STATE_DIR="/var/run/mysql-proxy"
MYSQL_PROXY_PORT="$1"

if [ -z $MYSQL_PROXY_PORT ] ; then #MYSQL Proxy port not specified
   echo "MYSQL Proxy port must be specified."
   exit 1
fi

# Installs MySQL Proxy.
function install_mysql_proxy {
   # Create user & group:
   if ! grep -iq "^$MYSQL_PROXY_GROUP" /etc/group ; then #group does not exist
      groupadd $MYSQL_PROXY_GROUP
   fi
   if ! grep -iq "^$MYSQL_PROXY_USER" /etc/passwd ; then #user does not exist
      useradd -M -r --shell /sbin/nologin --home-dir $MYSQL_PROXY_HOME_DIR --gid $MYSQL_PROXY_GROUP $MYSQL_PROXY_USER
   fi
   # Download & install files:
   cd ~
   wget $MYSQL_PROXY_URI #obtain precompiled binary files
   tar -zxf mysql*.tar.gz #unpack gzip archive
   mkdir $MYSQL_PROXY_HOME_DIR #create installation folder   
   cd mysql*
   mv --force --target-directory=$MYSQL_PROXY_HOME_DIR * #move files to installation folder - no need for compilation
   # Make binaries availiable to PATH:
   PATH=$PATH:$MYSQL_PROXY_HOME_DIR/bin
   export PATH
   echo -e "PATH=\$PATH:$MYSQL_PROXY_HOME_DIR/bin\n\
export PATH" > /etc/profile.d/mysql-proxy.sh #make changes to PATH permanent for all users
   chmod u=rw,g=r,o=r /etc/profile.d/mysql-proxy.sh
   # Configure (+ set logs):
   echo -e "[mysql-proxy]\n\
basedir=$MYSQL_PROXY_HOME_DIR\n\
user=$MYSQL_PROXY_USER\n\
pid-file=$MYSQL_PROXY_STATE_DIR/mysql-proxy.pid\n\
log-file=$MYSQL_PROXY_LOG_DIR/mysql-proxy.log\n\
log-level=info\n\
log-use-syslog=false\n\
proxy-skip-profiling=true\n\
keepalive=true\n\
proxy-address=:$MYSQL_PROXY_PORT\n\
lua-path=$MYSQL_PROXY_HOME_DIR/share/doc/mysql-proxy/?.lua\n\
proxy-lua-script=$MYSQL_PROXY_HOME_DIR/share/doc/mysql-proxy/rw-splitting.lua" > /etc/mysql-proxy.conf #create/overwrite mysql-proxy configuration file
   chmod u=rw,g=r,o= /etc/mysql-proxy.conf
   # Set daemon:
   echo_mysql_proxy_initd > /etc/init.d/mysql-proxy #create/overwrite mysql-proxy init.d script
   sed -i -e "s|^\(MYSQL_PROXY_HOME_DIR\)\(\s*=\s*\).*$|\1=$MYSQL_PROXY_HOME_DIR|" /etc/init.d/mysql-proxy #set home directory
   sed -i -e "s|^\(MYSQL_PROXY_CONF_FILE\)\(\s*=\s*\).*$|\1=/etc/mysql-proxy.conf|" /etc/init.d/mysql-proxy #set conf file
   sed -i -e "s|^\(MYSQL_PROXY_STATE_DIR\)\(\s*=\s*\).*$|\1=$MYSQL_PROXY_STATE_DIR|" /etc/init.d/mysql-proxy #set state directory
   chmod u=rwx,g=rx,o= /etc/init.d/mysql-proxy #make executable
   chkconfig --add mysql-proxy
   chkconfig --level 35 mysql-proxy on
   service mysql-proxy start #start daemon for the first time
   # Set firewall:
   allow_tcp $MYSQL_PROXY_PORT
   # Collect garbage:
   cd ~
   rm -rf mysql*
}

# Adds a new backend server to MySQL Proxy.
# MySQL proxy should be installed beforehand.
# $1 hostname of the backend server.
# $2 false if backend server is read only, true if not.
# $3 port of the backend server.
function add_mysql_proxy_backend {
   local host=$1
   local writable=${2-true}
   local port=${3-3306}
   if grep -q "$host:$MYSQL_PROXY_PORT" /etc/mysql-proxy.conf ; then #backend server is already added
      echo "The backend server you specified is already added to mysql-proxy."
   else #backend server may be added
      if $writable ; then
         if grep -q "^proxy-backend-addresses=" /etc/mysql-proxy.conf ; then #proxy-backend-addresses option already exists
            sed -i -e "s|^\(proxy-backend-addresses=\)\(.*\)$|\1\2,|" /etc/mysql-proxy.conf #append comma character to the end
         else #proxy-backend-addresses option is not set
            echo -e "proxy-backend-addresses=" >> /etc/mysql-proxy.conf #append empty proxy-backend-addresses option to file
         fi
         sed -i -e "s|^\(proxy-backend-addresses=\)\(.*\)$|\1\2$host:$MYSQL_PROXY_PORT|" /etc/mysql-proxy.conf #append $host:$MYSQL_PROXY_PORT to file
      else
         if grep -q "^proxy-read-only-backend-addresses=" /etc/mysql-proxy.conf ; then #proxy-read-only-backend-addresses option already exists
            sed -i -e "s|^\(proxy-read-only-backend-addresses=\)\(.*\)$|\1\2,|" /etc/mysql-proxy.conf #append comma character to the end
         else #proxy-backend-addresses option is not set
            echo -e "proxy-read-only-backend-addresses=" >> /etc/mysql-proxy.conf #append empty proxy-read-only-backend-addresses option to file
         fi
         sed -i -e "s|^\(proxy-read-only-backend-addresses=\)\(.*\)$|\1\2$host:$MYSQL_PROXY_PORT|" /etc/mysql-proxy.conf #append $host:$MYSQL_PROXY_PORT to file
      fi
      service mysql-proxy restart #restart mysql-proxy for the changes to take effect
   fi
}

# Removes a backend server from MySQL Proxy.
# MySQL proxy should be installed beforehand.
# $1 hostname of the backend server.
# $2 port of the backend server.
function remove_mysql_proxy_backend {
   local host=$1
   local port=${2-3306}
   if grep -q "$host:$MYSQL_PROXY_PORT" /etc/mysql-proxy.conf ; then #backend server exists
      sed -i -e "s|,\?$host:$MYSQL_PROXY_PORT||" /etc/mysql-proxy.conf #remove ",host:port" from configuration file
      sed -i -e "s|=,||" /etc/mysql-proxy.conf #make sure that "=" is followed by "host:port" without comma "," in between
      sed -i -e "/^proxy-backend-addresses=$/d" /etc/mysql-proxy.conf #delete proxy-backend-addresses if empty
      sed -i -e "/^proxy-read-only-backend-addresses=$/d" /etc/mysql-proxy.conf #delete proxy-read-only-backend-addresses if empty
      service mysql-proxy restart #restart mysql-proxy for the changes to take effect
   else #backend server does not exist
      echo "The backend server you specified does not exists in mysql-proxy configuration file."
   fi
}

# Echoes MySQL Proxy init.d script.
function echo_mysql_proxy_initd {
   echo -n \
'#!/bin/sh
#
# mysql-proxy This script starts and stops the mysql-proxy daemon
#
# chkconfig: - 78 30
# processname: mysql-proxy
# description: mysql-proxy is a proxy daemon to mysql

# Source function library.
. /etc/init.d/functions

# Source networking configuration.
. /etc/sysconfig/network

# Check that networking is up.
[ ${NETWORKING} = "no" ] && exit 0

MYSQL_PROXY_HOME_DIR=/opt/mysql
MYSQL_PROXY_CONF_FILE=/etc/mysql-proxy.conf
MYSQL_PROXY_STATE_DIR=/var/run

case "$1" in
   start)
      echo "Starting mysql-proxy:"
      daemon $NICELEVEL $MYSQL_PROXY_HOME_DIR/bin/mysql-proxy --daemon --defaults-file=$MYSQL_PROXY_CONF_FILE
      ;;
   stop)
      echo "Stoping mysql-proxy:"
      killproc mysql-proxy
      rm -f $MYSQL_PROXY_STATE_DIR/mysql-proxy.pid
      ;;
   restart)
      $0 stop
      sleep 3
      $0 start
      ;;
   status)
      status mysql-proxy
      ;;
   *)
      echo "Usage: mysql-proxy {start|stop|restart|status}"
      exit 1
esac

exit 0'
}
