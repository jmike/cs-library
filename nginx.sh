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

NGINX_URI="http://nginx.org/download/nginx-1.0.6.tar.gz"
NGINX_USER="www"
NGINX_GROUP="www"
NGINX_HOME_DIR="/opt/nginx"
HTTP_PORT="$1"
HTTPS_PORT="$2"

if [ -z $HTTP_PORT ] ; then #HTTP port not specified
   echo "HTTP port must be specified."
   exit 1
fi

if [ -z $HTTPS_PORT ] ; then #HTTPS port not specified
   echo "HTTPS port must be specified."
   exit 1
fi

# Installs Nginx HTTP server.
function install_nginx_http {
   # Install prerequisites:
   yum -y install gcc openssl openssl-devel pcre pcre-devel zlib zlib-devel
   # Create user & group:
   if ! grep -iq "^$NGINX_GROUP" /etc/group ; then #group does not exist
      groupadd $NGINX_GROUP
   fi
   if ! grep -iq "^$NGINX_USER" /etc/passwd ; then #user does not exist
      useradd -M -r --shell /sbin/nologin --home-dir $NGINX_HOME_DIR --gid $NGINX_GROUP $NGINX_USER
   fi
   # Donwload, compile & install files:
   cd ~
   wget $NGINX_URI #obtain source code
   tar -zxf nginx*.tar.gz #unpack gzip archive
   cd nginx*
   ./configure --user=$NGINX_USER --group=$NGINX_GROUP \
--prefix=$NGINX_HOME_DIR \
--conf-path=/etc/nginx/nginx.conf \
--error-log-path=/var/log/nginx-error.log \
--pid-path=/var/run/nginx.pid \
--lock-path=/var/run/nginx.lock \
--http-log-path=/var/log/nginx-http.log \
--http-client-body-temp-path=/var/tmp/nginx_client_body \
--http-proxy-temp-path=/var/tmp/nginx_proxy \
--http-fastcgi-temp-path=/var/tmp/nginx_fastcgi \
--http-uwsgi-temp-path=/var/tmp/nginx_uwsgi \
--http-scgi-temp-path=/var/tmp/nginx_scgi \
--with-http_ssl_module \
--with-http_realip_module \
--with-http_flv_module \
--with-http_gzip_static_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--without-http_geo_module \
--without-http_map_module \
--without-http_proxy_module \
--without-http_userid_module \
--without-http_memcached_module \
--without-http_limit_zone_module \
--without-http_limit_req_module
   make #compile
   make install #install
   # Make binaries availiable to PATH:
   PATH=$PATH:$NGINX_HOME_DIR/sbin
   export PATH
   echo -e "PATH=\$PATH:$NGINX_HOME_DIR/sbin\n\
export PATH" > /etc/profile.d/nginx.sh #make changes to PATH permanent for all users
   chmod u=rw,g=r,o=r /etc/profile.d/nginx.sh
   # Create temp directories:
   mkdir -m u=rw,g=rw,o= /var/tmp/nginx_client_body
   mkdir -m u=rw,g=rw,o= /var/tmp/nginx_proxy
   mkdir -m u=rw,g=rw,o= /var/tmp/nginx_fastcgi
   mkdir -m u=rw,g=rw,o= /var/tmp/nginx_uwsgi
   mkdir -m u=rw,g=rw,o= /var/tmp/nginx_scgi
   # Create sites configuration directory:
   mkdir -m u=rw,g=rw,o= /etc/nginx/sites
   # Configure:

   # Set daemon:
   cd ~
   echo_nginx_initd > /etc/init.d/nginx #create/overwrite init.d script
   sed -i -e "s|^\(NGINX_CONF_FILE\)\(\s\?=\s\?\)\(.*\)$|\1=\"/etc/nginx/nginx.conf\"|" /etc/init.d/nginx #set configuration file path
   sed -i -e "s|^\(lockfile\)\(\s\?=\s\?\)\(.*\)$|\1=/var/run/nginx.lock|" /etc/init.d/nginx #set lock file
   chmod u=rwx,g=rx,o= /etc/init.d/nginx #make executable
   chkconfig --add nginx
   chkconfig --level 35 nginx on
   service nginx start #start daemon for first time
   # Set firewall:
   allow_tcp $HTTP $HTTPS
   # Collect garbage:
   cd ~
   rm -rf nginx*
}

# Echoes nginx initd script.
function echo_nginx_initd {
   echo -n \
'#!/bin/sh
#
# nginx – this script starts and stops the nginx daemon
#
# chkconfig: - 85 15
# description: Nginx is an HTTP(S) server, HTTP(S) reverse \
# proxy and IMAP/POP3 proxy server
# processname: nginx

# Source function library.
. /etc/rc.d/init.d/functions

# Source networking configuration.
. /etc/sysconfig/network

# Check that networking is up.
[ "$NETWORKING" = "no" ] && exit 0

nginx="/opt/nginx/sbin/nginx"
prog=$(basename $nginx)
lockfile=/var/lock/subsys/nginx

NGINX_CONF_FILE="/opt/nginx/conf/nginx.conf"

start() {
   [ -x $nginx ] || exit 5
   [ -f $NGINX_CONF_FILE ] || exit 6
   echo -n $"Starting $prog: "
   daemon $nginx -c $NGINX_CONF_FILE
   retval=$?
   echo
   [ $retval -eq 0 ] && touch $lockfile
   return $retval
}

stop() {
   echo -n $"Stopping $prog: "
   killproc $prog -QUIT
   retval=$?
   echo
   [ $retval -eq 0 ] && rm -f $lockfile
   return $retval
}

restart() {
   configtest || return $?
   stop
   start
}

reload() {
   configtest || return $?
   echo -n $"Reloading $prog: "
   killproc $nginx -HUP
   RETVAL=$?
   echo
}

force_reload() {
   restart
}

configtest() {
   $nginx -t -c $NGINX_CONF_FILE
}

rh_status() {
   status $prog
}

rh_status_q() {
   rh_status >/dev/null 2>&1
}

case "$1" in
   start)
      rh_status_q && exit 0
      $1
      ;;
   stop)
      rh_status_q || exit 0
      $1
      ;;
   restart|configtest)
      $1
      ;;
   reload)
      rh_status_q || exit 7
      $1
      ;;
   force-reload)
      force_reload
      ;;
   status)
      rh_status
      ;;
   condrestart|try-restart)
      rh_status_q || exit 0
      ;;
   *)
      echo $"Usage: $0 {start|stop|status|restart|condrestart|try-restart|reload|force-reload|configtest}"
      exit 2
esac'
}
