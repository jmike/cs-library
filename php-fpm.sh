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

PHP_URI="http://gr.php.net/get/php-5.3.8.tar.gz/from/uk.php.net/mirror"
PHP_USER="php"
PHP_GROUP="php"
PHP_HOME_DIR="/opt/php"
PHP_CONF_DIR="/etc/php"
PHP_LOG_DIR="/var/log/php"
PHP_STATE_DIR="/var/run/php"

# Installs PHP-FPM.
function install_php_fpm {
   # Install prerequisites:
   yum -y install gcc zlib zlib-devel libxml2 libxml2-devel curl curl-devel libjpeg libjpeg-devel libpng libpng-devel libmcrypt libmcrypt-devel mysql mysql-devel libtidy libtidy-devel libc-client libc-client-devel libtool-ltdl libtool-ltdl-devel
   # Create user & group:
   if ! grep -iq "^$PHP_GROUP" /etc/group ; then #group does not exist
      groupadd $PHP_GROUP
   fi
   if ! grep -iq "^$PHP_USER" /etc/passwd ; then #user does not exist
      useradd -M -r --shell /sbin/nologin --home-dir $PHP_HOME_DIR --gid $PHP_GROUP $PHP_USER
   fi
   # Donwload, compile & install files:
   cd ~
   wget $PHP_URI #obtain source code
   tar -zxf php*.tar.gz #unpack gzip archive
   cd php*
   ./configure --enable-fpm --with-fpm-user=$PHP_USER --with-fpm-group=$PHP_GROUP \
--prefix=$PHP_HOME_DIR \
--with-config-file-path=$PHP_CONF_DIR/php.ini \
--with-config-file-scan-dir=$PHP_CONF_DIR \
--with-layout=GNU \
--with-libdir=lib64 \
--enable-mbstring \
--enable-pcntl \
--enable-soap \
--enable-sockets \
--enable-sqlite-utf8 \
--enable-zip \
--with-gd \
--with-zlib \
--with-curl \
--with-jpeg-dir \
--with-png-dir \
--with-zlib-dir \
--with-gettext \
--with-mcrypt \
--with-mysql=mysqlnd \
--with-mysqli=mysqlnd \
--with-pdo-mysql=mysqlnd \
--with-pdo-sqlite \
--with-tidy \
--with-pear \
--disable-debug
   make #compile
   make install #install
   # Make binaries availiable to PATH:
   PATH=$PATH:$PHP_HOME_DIR/sbin
   export PATH
   echo -e "PATH=\$PATH:$PHP_HOME_DIR/sbin\n\
export PATH" > /etc/profile.d/php-fpm.sh #make changes to PATH permanent for all users
   chmod u=rw,g=r,o=r /etc/profile.d/php-fpm.sh
   # Configure:
   mv --force $PHP_HOME_DIR/etc/php-fpm.conf.default $PHP_CONF_DIR/php-fpm.conf #move conf file
   sed -i -e "s|^\(;\?\)\(pid\)\(\s\?=\s\?\)\(.*\)$|\2 = $PHP_STATE_DIR/php-fpm.pid|" $PHP_CONF_DIR/php-fpm.conf #set PID file
   sed -i -e "s|^\(;\?\)\(error_log\)\(\s\?=\s\?\)\(.*\)$|\2 = $PHP_LOG_DIR/error.log|" $PHP_CONF_DIR/php-fpm.conf #set error log
   sed -i -e "s|^\(;\?\)\(log_level\)\(\s\?=\s\?\)\(.*\)$|\2 = notice|" $PHP_CONF_DIR/php-fpm.conf #log messages of "notice" level or higher
   sed -i -e "s|^\(;\?\)\(emergency_restart_threshold\)\(\s\?=\s\?\)\(.*\)$|\2 = 10|" $PHP_CONF_DIR/php-fpm.conf
   sed -i -e "s|^\(;\?\)\(emergency_restart_interval\)\(\s\?=\s\?\)\(.*\)$|\2 = 1m|" $PHP_CONF_DIR/php-fpm.conf
   sed -i -e "s|^\(;\?\)\(process_control_timeout\)\(\s\?=\s\?\)\(.*\)$|\2 = 5s|" $PHP_CONF_DIR/php-fpm.conf
   sed -i -e "s|^\(;\?\)\(daemonize\)\(\s\?=\s\?\)\(.*\)$|\2 = yes|" $PHP_CONF_DIR/php-fpm.conf
   chmod u=rw,g=r,o= $PHP_CONF_DIR/php-fpm.conf
   # Delete default [www] pool:
   sed -i -e "/^;\s\+Pool Definitions/,$ d" $PHP_CONF_DIR/php-fpm.conf
   # Set php.ini:
   cd ~/php* 
   /bin/cp -rf php.ini-production $PHP_CONF_DIR/php.ini
   chmod u=rw,g=r,o= $PHP_CONF_DIR/php.ini
   # Set logs:
   mkdir -m u=rw,g=rw,o= $PHP_LOG_DIR
   touch $PHP_LOG_DIR/error.log
   chmod u=rw,g=r,o= $PHP_LOG_DIR/error.log
   # Set daemon:
   cd ~/php* 
   /bin/cp -rf sapi/fpm/init.d.php-fpm.in /etc/init.d/php-fpm
   sed -i -e "s|@prefix@|$PHP_HOME_DIR|" /etc/init.d/php-fpm
   sed -i -e "s|@exec_prefix@|$PHP_HOME_DIR|" /etc/init.d/php-fpm
   sed -i -e "s|@sbindir@|$PHP_HOME_DIR/sbin|" /etc/init.d/php-fpm
   sed -i -e "s|@sysconfdir@|/etc|" /etc/init.d/php-fpm
   sed -i -e "s|@localstatedir@|/var|" /etc/init.d/php-fpm
   sed -i -e "s|^\(php_opts\)\(\s\?=\s\?\)\"\([^\"]*\)\"$|\1=\"--fpm-config $PHP_CONF_DIR/php-fpm.conf -c $PHP_CONF_DIR/php.ini\"|" /etc/init.d/php-fpm
   chmod u=rwx,g=rx,o= /etc/init.d/php-fpm #make executable
   chkconfig --add php-fpm
   chkconfig --level 35 php-fpm on
   # Service cannot be started because no pools have yet been configured.
   # Collect garbage:
   cd ~
   rm -rf php*
}

# Adds new PHP FPM pool.
# PHP-FPM should be installed beforehand.
# $1 the name of the pool
# $2 the unix user, which the pool will be running under
# $3 the unix group, which the pool will be running under
# $4 the home directory of the pool
# $5 the port of the pool
function add_php_fpm_pool {
   local name=$1
   local user=$2
   local group=$3
   local home=$4
   local port=$5
   # Check if $user exists:
   if ! grep -iq "^$user" /etc/passwd ; then #user does not exist
      echo "User \"$user\" does not exist. Please run useradd and try again."
      return 1 #exit
   fi
   # Check if $group exists:
   if ! grep -iq "^$group" /etc/group ; then #group does not exist
      echo "Group \"$group\" does not exist. Please run groupadd and try again."
      return 1 #exit
   fi
   # Check if $home directory exists:
   if [ ! -d "$home" ]; then
      echo "Home directory $home does not exist. Please retry, entering a valid path."
      return 1 #exit
   fi
   # Check if $port is taken:
   if netstat -lnt | grep -q "$port" ; then #port is already taken
      echo "Port $port is already taken. Please retry, entering another port."
      return 1 #exit
   fi
   # Set logs:
   touch /var/log/php-fpm/$name-access.log
   chmod u=rw,g=r,o= /var/log/php-fpm/$name-access.log
   touch /var/log/php-fpm/$name-slow.log
   chmod u=rw,g=r,o= /var/log/php-fpm/$name-slow.log
   touch /var/log/php-fpm/$name-error.log
   chmod u=rw,g=r,o= /var/log/php-fpm/$name-error.log
   # Configure new pool:
   echo -e "\n\
[$name]\n\
listen = $port\n\
user = $user\n\
group = $group\n\
pm = dynamic\n\
pm.max_children = 50\n\
pm.start_servers = 20\n\
pm.min_spare_servers = 5\n\
pm.max_spare_servers = 35\n\
pm.max_requests = 500\n\
pm.status_path = /status\n\
ping.path = /ping\n\
ping.response = pong\n\
access.log = /var/log/php-fpm/$name-access.log\n\
request_terminate_timeout = 300s\n\
request_slowlog_timeout = 120s\n\
slowlog = /var/log/php-fpm/$name-slow.log\n\
chroot = $home\n\
chdir = /\n\
php_flag[display_errors] = off\n\
php_admin_value[error_log] = /var/log/php-fpm/$name-error.log\n\
php_admin_flag[log_errors] = on\n\
php_admin_value[memory_limit] = 32M" >> /etc/php-fpm.conf
   # Set firewall:
   iptables --delete Chuck_Norris --jump REJECT --reject-with icmp-host-prohibited
   iptables --append Chuck_Norris --match state --state NEW --match tcp --protocol tcp --destination-port $port --jump ACCEPT
   iptables --append Chuck_Norris --jump REJECT --reject-with icmp-host-prohibited #deny everything else
   service iptables save
   service iptables restart
   # Restart daemon:
   service php-fpm restart
}

# Removes new PHP FPM pool.
# PHP-FPM should be installed beforehand.
# $1 the name of the pool
function remove_php_fpm_pool {
   local name=$1
   # Find port:
   local from_line=$(sed -n "/\[$name\]/=" /etc/php-fpm.conf) #recover the line number of [$name]
   local port=$(cat /etc/php-fpm.conf | sed -n -e "$from_line,/^\[.*\]$/ s|listen\s*=\s*\([0-9]\+\)|\1|p") #search for port from [$name] to first empty line
   # Unset firewall:
   iptables --delete Chuck_Norris --match state --state NEW --match tcp --protocol tcp --destination-port $port --jump ACCEPT
   service iptables save
   service iptables restart
   # Delete pool from configuration file:
   sed -i -e "$from_line,/^\s*$/d" /etc/php-fpm.conf #remove lines from [$name] to first empty line
   # Restart daemon:
   service php-fpm restart
   # Unset logs:
   rm -f /var/log/php-fpm/$name-*.log
}
