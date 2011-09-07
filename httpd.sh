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

APR_URI="http://www.mirrorservice.org/sites/ftp.apache.org/apr/apr-1.4.5.tar.gz"
APR_CONF_DIR="/etc/apr"
APR_STATE_DIR="/var/run/apr"
APR_HOME="/opt/apr"

APU_URI="http://www.mirrorservice.org/sites/ftp.apache.org/apr/apr-util-1.3.12.tar.gz"
APU_CONF_DIR="/etc/apu"
APU_STATE_DIR="/var/run/apu"
APU_HOME="/opt/apu"

HTTPD_URI="http://www.mirrorservice.org/sites/ftp.apache.org/httpd/httpd-2.3.14-beta.tar.gz"
HTTPD_USER="httpd"
HTTPD_GROUP="httpd"
HTTPD_HOME_DIR="/opt/httpd"
HTTPD_CONF_DIR="/etc/httpd"
HTTPD_LOG_DIR="/var/log/httpd"
HTTPD_STATE_DIR="/var/run/httpd"
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

# Installs Apache Portable Runtime.
# APR provides a platform independent interface for software projects, such as Apache HTTPD.
# Please refer to http://apr.apache.org for further study.
function install_apr {
   # Install prerequisites:
   yum -y install gcc libtool-ltdl libtool-ltdl-devel
   # Donwload, compile & install files:
   cd ~
   wget $APR_URI #obtain source code
   tar -zxf apr*.tar.gz #unpack gzip archive
   cd apr*
   ./configure \
--prefix=$APR_HOME \
--sysconfdir=$APR_CONF_DIR \
--localstatedir=$APR_STATE_DIR
   make #compile
   make install #install
   # Collect garbage:
   cd ~
   rm -rf apr*
}

# Installs Apache Portable Runtime Utilities.
# APR should be installed beforehand.
# Please refer to http://apr.apache.org for further study.
function install_apu {
   # Install prerequisites:
   yum -y install gcc libtool-ltdl libtool-ltdl-devel
   # Donwload, compile & install files:
   cd ~
   wget $APU_URI #obtain source code
   tar -zxf apr-util*.tar.gz #unpack gzip archive
   cd apr-util*
   ./configure \
--prefix=$APU_HOME \
--sysconfdir=$APU_CONF_DIR \
--localstatedir=$APU_STATE_DIR \
--with-apr=$APR_HOME/bin/apr-1-config
   make #compile
   make install #install
   # Collect garbage:
   cd ~
   rm -rf apr-util*                                              
}

# Installs Apache HTTPD.
# APR and APU should be installed beforehand.
# Please refer to http://httpd.apache.org for further study.
# $1 the directory out of which documents (websites) will be served {REQUIRED}
function install_httpd {   
   local root_dir="$1"
   # Make sure document root directory is specified:
   if [ -z $root_dir ] ; then
      echo "HTTPD's document root directory must be specified."
      return 0 #exit
   fi
   # Make sure document root directory exists:
   if [ ! -d $root_dir ]; then
      echo "Directory \"$root_dir\" does not exist."
      return 0 #exit
   fi
   # Install prerequisites:
   yum -y install gcc libtool-ltdl libtool-ltdl-devel openssl openssl-devel pcre pcre-devel
   # Create user & group:
   if ! grep -iq "^$HTTPD_GROUP" /etc/group ; then #group does not exist
      groupadd $HTTPD_GROUP
   fi
   if ! grep -iq "^$HTTPD_USER" /etc/passwd ; then #user does not exist
      useradd -M -r --shell /sbin/nologin --home-dir $HTTPD_HOME_DIR --gid $HTTPD_GROUP $HTTPD_USER
   fi
   # Donwload, compile & install files:
   cd ~
   wget $HTTPD_URI #obtain source code
   tar -zxf httpd*.tar.gz #unpack gzip archive
   cd httpd*
   ./configure \
--prefix=$HTTPD_HOME_DIR \
--sysconfdir=$HTTPD_CONF_DIR \
--localstatedir=$HTTPD_STATE_DIR \
--with-apr=$APR_HOME/bin/apr-1-config \
--with-apr-util=$APU_HOME/bin/apu-1-config \
--enable-http --with-port=80 \
--enable-ssl --with-sslport=443 \
--enable-unixd=static \
--with-mpm=worker \
--enable-authz-core=static \
--enable-access-compat=static \
--enable-proxy=static --enable-proxy-fcgi=static \
--enable-remoteip=static \
--enable-rewrite=static \
--enable-expires=static \
--enable-headers=static \
--enable-dir=static \
--enable-log-config=static
   make #compile
   make install #install
   # Make binaries availiable to PATH:
   PATH=$PATH:$HTTPD_HOME_DIR/bin
   export PATH
   echo -e "PATH=\$PATH:$HTTPD_HOME_DIR/bin\n\
export PATH" > /etc/profile.d/httpd.sh #make changes to PATH permanent for all users
   chmod u=rw,g=r,o=r /etc/profile.d/httpd.sh
   # Make sure only root has read access to httpd's binaries:
   chown --recursive root:root $HTTPD_HOME_DIR/bin
   chmod u=rwx,g=rx,o= $HTTPD_HOME_DIR/bin
   # Make sure only root has read access to httpd's config files:
   chown --recursive root:root $HTTPD_CONF_DIR
   chmod u=rwx,g=rx,o= $HTTPD_CONF_DIR
   # Create sites directory:
   mkdir -m u=rw,g=rw,o= $HTTPD_CONF_DIR/sites
   # Configure:
   sed -i -e "s|^\(#\?\)\(ServerRoot\).*$|\2 \"$HTTPD_CONF_DIR\"|" $HTTPD_CONF_DIR/httpd.conf #set home directory
   sed -i \
-e "/^PidFile/d" \
-e "/^ServerRoot/a \
PidFile \"$HTTPD_STATE_DIR/httpd.pid\"" \
$HTTPD_CONF_DIR/httpd.conf #set PID file
   sed -i -e "s|^\(#\?\)\(ErrorLog\).*$|\2 \"$HTTPD_LOG_DIR/error.log\"|" $HTTPD_CONF_DIR/httpd.conf #set error log
   sed -i -e "/^<IfModule log_config_module>$/,/^<\/IfModule>$/c \
<IfModule log_config_module>\n\
   LogFormat \"%h %l %u %t \\\"%r\\\" %>s %b \\\"%{Referer}i\\\" \\\"%{User-Agent}i\\\"\" combined\n\
   LogFormat \"%h %l %u %t \\\"%r\\\" %>s %b\" common\n\
   CustomLog \"$HTTPD_LOG_DIR/access.log\" combined\n\
<\/IfModule>" $HTTPD_CONF_DIR/httpd.conf #set access log
   sed -i -e "s|^\(#\?\)\(LogLevel\).*$|\2 warn|" $HTTPD_CONF_DIR/httpd.conf #log error messages of $e level or higher
   sed -i -e "s|^\(#\?\)\(ServerAdmin\).*$|\2 hostmaster@cloudedsunday.com|" $HTTPD_CONF_DIR/httpd.conf #set admininstrator e-mail address
   sed -i -e "s|^\(#\?\)\(ServerName\).*$|\2 $(hostname):80|" $HTTPD_CONF_DIR/httpd.conf #set server name
   sed -i \
-e "/^ServerSignature/d" \
-e "/^ServerName/a \
ServerSignature Off" \
$HTTPD_CONF_DIR/httpd.conf #hide version number from auto-generated files, such as 404 error pages
   sed -i \
-e "/^ServerTokens/d" \
-e "/^ServerSignature/a \
ServerTokens Prod" \
$HTTPD_CONF_DIR/httpd.conf #hide version number from Server HTTP header
   sed -i -e "s|^\(#\?\)\(User\).*$|\2 $HTTPD_USER|" \
-e "s|^\(#\?\)\(Group\).*$|\2 $HTTPD_GROUP|" \
$HTTPD_CONF_DIR/httpd.conf #run httpd under its own user account and group
   sed -i -e "/^<Directory \/>$/,/^<\/Directory>$/c \
<Directory \/>\n\
   Require all denied\n\
   Options None\n\
   AllowOverride None\n\
<\/Directory>" $HTTPD_CONF_DIR/httpd.conf #ensure that files outside the document root are not served
   sed -i -e "s|^\(#\?\)\(DocumentRoot\).*$|\2 $root_dir|" $HTTPD_CONF_DIR/httpd.conf #change document root
   sed -i -e "/^<Directory \".\+\/htdocs\">$/,/^<\/Directory>$/c \
<Directory \"$root_dir\">\n\
   Require all granted\n\
   Options None\n\
   AllowOverride All\n\
<\/Directory>" $HTTPD_CONF_DIR/httpd.conf #set document root options
   sed -i -e "s|^LoadModule.*$|#&|" $HTTPD_CONF_DIR/httpd.conf #disable any unnecessary modules
   sed -i -e "/^<IfModule dir_module>$/,/^<\/IfModule>$/c \
<IfModule dir_module>\n\
   DirectoryIndex index.html index.htm default.html default.htm\n\
<\/IfModule>" $HTTPD_CONF_DIR/httpd.conf #set directory index
   sed -i \
-e "/^Timeout/d" \
-e "$ a \
Timeout 60" \
$HTTPD_CONF_DIR/httpd.conf #lower the Timeout value
   sed -i \
-e "/^LimitRequestBody/d" \
-e "$ a \
LimitRequestBody 31457280" \
$HTTPD_CONF_DIR/httpd.conf #limit large requests
   sed -i \
-e "/^LimitXMLRequestBody/d" \
-e "$ a \
LimitXMLRequestBody 31457280" \
$HTTPD_CONF_DIR/httpd.conf #limit the size of an XML Body
   sed -i \
-e "/^Include/d" \
-e "$ a \
Include optional $HTTPD_CONF_DIR/sites/*.conf" \
$HTTPD_CONF_DIR/httpd.conf #include virtual-hosts configuration files
   # Set logs:
   mkdir -m u=rw,g=r,o= $HTTPD_LOG_DIR
   touch $HTTPD_LOG_DIR/error.log
   chmod u=rw,g=r,o= $HTTPD_LOG_DIR/error.log
   touch $HTTPD_LOG_DIR/access.log
   chmod u=rw,g=r,o= $HTTPD_LOG_DIR/access.log
   # Integrate into logrotate:
   echo -n \
"$HTTPD_LOG_DIR/error.log {
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
}

$HTTPD_LOG_DIR/access.log {
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
}" > /etc/logrotate.d/httpd
   chmod u=rw,g=r,o= /etc/logrotate.d/httpd
   # Set daemon:
   echo_httpd_initd > /etc/init.d/httpd #create/overwrite httpd init.d script
   sed -i -e "s|^\(apachectl\)\(\s*=\s*\).*$|\1=$HTTPD_HOME_DIR/bin/apachectl|" /etc/init.d/httpd #set path to the apachectl script
   sed -i -e "s|^\(httpd\)\(\s*=\s*\).*$|\1=$HTTPD_HOME_DIR/bin/httpd|" /etc/init.d/httpd #set path to the server binary
   sed -i -e "s|^\(pid\)\(\s*=\s*\).*$|\1=$HTTPD_STATE_DIR/httpd.pid|" /etc/init.d/httpd #set PID file
   sed -i -e "s|^\(lock\)\(\s*=\s*\).*$|\1=$HTTPD_STATE_DIR/httpd.lock|" /etc/init.d/httpd #set lock file
   chmod u=rwx,g=rx,o= /etc/init.d/httpd #make executable
   chkconfig --add httpd
   chkconfig --level 35 httpd on
   service httpd start #start daemon for first time
   # Set firewall:
   iptables --delete Chuck_Norris --jump REJECT --reject-with icmp-host-prohibited
   iptables --append Chuck_Norris --match state --state NEW --match tcp --protocol tcp --destination-port 80 --jump ACCEPT
   iptables --append Chuck_Norris --match state --state NEW --match tcp --protocol tcp --destination-port 443 --jump ACCEPT
   iptables --append Chuck_Norris --jump REJECT --reject-with icmp-host-prohibited #deny everything else
   service iptables save
   service iptables restart
   # Collect garbage:
   cd ~
   rm -rf httpd*
}

# Adds the specified site to Apache HTTPD.
# $1 the domain name of the site, i.e. "cloudedsunday.com" {REQUIRED}
# $2 the root directory of the site, i.e. "/mnt/athos/client-345/cloudedsunday.com" {REQUIRED}
function add_httpd_site {
   local name="$1"
   local root_dir="$2"
   # Make sure site's name is specified:
   if [ -z $name ] ; then
      echo "Site's domain name must be specified."
      return 0 #exit
   fi
   # Make sure site's root directory is specified:
   if [ -z $root_dir ] ; then
      echo "Site's root directory must be specified."
      return 0 #exit
   fi
   # Make sure site's root directory exists:
   if [ ! -d $root_dir ]; then
      echo "Directory \"$root_dir\" does not exist."
      return 0 #exit
   fi
   # Make sure site's content directory exists:
   if [ ! -d $root_dir/content ]; then
      echo "Directory \"$root_dir/content\" does not exist."
      return 0 #exit
   fi
   # Make sure site's log directory exists:
   if [ ! -d $root_dir/log ]; then
      echo "Directory \"$root_dir/log\" does not exist."
      return 0 #exit
   fi
   # Create site configuration file:
   echo -n \
"<VirtualHost *:80>
   ServerName $name
   DocumentRoot $root_dir/content
   LogLevel warn
   ErrorLog $root_dir/log/error.log
   CustomLog $root_dir/log/access.log combined
</VirtualHost>
" > $HTTPD_CONF_DIR/sites/$name.conf
   # Make sure configuration file is flawless:
   apachectl configtest #test configuration using apache control script
   if [ $? -gt 0 ] ; then #oh my, exit status implies there was an error
      rm -f $HTTPD_CONF_DIR/sites/$name.conf #remove flawed config file
      echo "Site not added. Configuration file contains errors."
      return 0 #exit
   fi
   # Create log files:
   touch $root_dir/log/error.log
   chmod u=rw,g=r,o=r $root_dir/log/error.log
   touch $root_dir/log/access.log
   chmod u=rw,g=r,o=r $root_dir/log/access.log
   # Integrate into logrotate:
   echo -n \
"$root_dir/log/error.log {
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
}

$root_dir/log/access.log {
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
}" > /etc/logrotate.d/$name.httpd
   chmod u=rw,g=r,o= /etc/logrotate.d/$name.httpd
   service httpd reload #reload config
}

# Removes the specified site from Apache HTTPD.
# $1 the domain name of the site, i.e. "cloudedsunday.com" {REQUIRED}
function remove_httpd_site {
   local name="$1"
   # Make sure site's name is specified:
   if [ -z $name ] ; then
      echo "Site's domain name must be specified."
      return 0 #exit
   fi
   # Make sure site's configuration exists:
   if [ ! -f $HTTPD_CONF_DIR/sites/$name.conf ]; then
      echo "Configuration file for \"$name\" does not exist."
      return 0 #exit
   fi
   # Remove site:
   rm -f $HTTPD_CONF_DIR/sites/$name.conf #remove config file
   rm -f /etc/logrotate.d/$name.httpd #remove logrotate file
   service httpd reload #reload config
}

# Adds the specified site as an alias to Apache HTTPD.
# $1 the domain name of the alias, i.e. "www.cloudedsunday.com" {REQUIRED}
# $2 the target domain name that alias will be pointing to, i.e. "cloudedsunday.com" {REQUIRED}
function add_httpd_alias {
   local alias="$1"
   local target="$2"
   # Make sure alias is specified:
   if [ -z $alias ] ; then
      echo "Alias' domain name must be specified."
      return 0 #exit
   fi
   # Make sure target is specified:
   if [ -z $target ] ; then
      echo "Target domain name must be specified."
      return 0 #exit
   fi
   # Make sure target of the alias exists:
   if [ -z "$(sed -n "/^\s*ServerName $target$/=" $HTTPD_CONF_DIR/sites/*.conf)" ] ; then #oh my, target hostname does not exist
      echo "Target domain name \"$target\" does not exist."
      return 0 #exit
   fi
   # Make sure alias is not already in use:
   sed -i -e "/^\s*ServerAlias $alias$/d" $HTTPD_CONF_DIR/sites/*.conf #delete alias directives if found
   # Add new alias to target site:
   sed -i -e "/^\s*ServerName $target$/ a \
\ \ \ ServerAlias $alias" \
$HTTPD_CONF_DIR/sites/*.conf #append ServerAlias directive after each ServerName that matches target hostname
   service httpd reload #reload config
}

# Removes the specified site alias from Apache HTTPD.
# $1 the hostname of the alias, i.e. "www.cloudedsunday.com" {REQUIRED}
function remove_httpd_alias {
   local alias="$1"
   # Make sure alias is specified:
   if [ -z $alias ] ; then
      echo "Alias' domain name must be specified."
      return 0 #exit
   fi
   # Make sure alias exists:
   if [ -z "$(sed -n "/^\s*ServerAlias $alias$/=" $HTTPD_CONF_DIR/sites/*.conf)" ] ; then #oh my, alias hostname does not exist
      echo "Alias hostname \"$alias\" does not exist."
      return 0 #exit
   fi
   # Remove alias from config files:
   sed -i -e "/^\s*ServerAlias $alias$/d" $HTTPD_CONF_DIR/sites/*.conf #delete alias directives if found
   service httpd reload #reload config
}

# Echoes HTTPD init.d script.
function echo_httpd_initd {
   echo -n \
'#!/bin/bash
#
# Startup script for the Apache Web Server
#
# chkconfig: - 85 15
# description: Apache is a World Wide Web server.  It is used to serve HTML files and CGI.
# processname: httpd

# Source function library.
. /etc/init.d/functions

# Source networking configuration.
. /etc/sysconfig/network

# Check that networking is up.
[ \${NETWORKING} = \"no\" ] && exit 0

# This will prevent initlog from swallowing up a pass-phrase prompt if
# mod_ssl needs a pass-phrase from the user.
INITLOG_ARGS=""

apachectl=/usr/local/apache2/bin/apachectl
httpd=/usr/local/apache2/bin/httpd
pid=$httpd/logs/httpd.pid
lock=/var/lock/subsys/httpd

prog=httpd
RETVAL=0

start() {
   echo -n $"Starting $prog: "
   daemon $httpd #you may add options here
   RETVAL=$?
   echo
   [ $RETVAL = 0 ] && touch $lock
   return $RETVAL
}

stop() {
   echo -n $"Stopping $prog: "
   killproc $httpd
   RETVAL=$?
   echo
   [ $RETVAL = 0 ] && rm -f $lock $pid
}

reload() {
   echo -n $"Reloading $prog: "
   killproc $httpd -HUP
   RETVAL=$?
   echo
}

case "$1" in
   start)
      start
      ;;
   stop)
      stop
      ;;
   status)
      status $httpd
      RETVAL=$?
      ;;
   restart)
      stop
      start
      ;;
   condrestart)
      if [ -f $pid ] ; then
         stop
         start
      fi
      ;;
   reload)
      reload
      ;;
   graceful|help|configtest|fullstatus)
      $apachectl $@
      RETVAL=$?
      ;;
   *)
      echo $"Usage: $prog {start|stop|restart|condrestart|reload|status"
      echo $"|fullstatus|graceful|help|configtest}"
      exit 1
esac

exit $RETVAL'
}
