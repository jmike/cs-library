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
source network.sh

MYSQL_URI="http://dev.mysql.com/get/Downloads/MySQL-5.5/mysql-5.5.15-linux2.6-x86_64.tar.gz/from/http://www.mirrorservice.org/sites/ftp.mysql.com/"
MYSQL_USER="mysql"
MYSQL_GROUP="mysql"
MYSQL_HOME_DIR="/opt/mysql"
MYSQL_LOG_DIR="/var/log/mysql"
MYSQL_STATE_DIR="/var/run/mysql"
MYSQL_PORT="$1"

if [ -z $MYSQL_PORT ] ; then #MYSQL port not specified
   echo "MYSQL port must be specified."
   exit 1
fi

# Installs MySQL relational database.
# Please refer to http://dev.mysql.com/doc/index.html for further study.
# $1 password for MySQL root account {REQUIRED}
function install_mysql {
   local password="$1"
   if [ -z $password ] ; then #password not specified
      echo "MySQL root password must be specified."
      return 0 #exit
   fi
   # Create user & group:
   if ! grep -iq "^$MYSQL_GROUP" /etc/group ; then #group does not exist
      groupadd $MYSQL_GROUP
   fi
   if ! grep -iq "^$MYSQL_USER" /etc/passwd ; then #user does not exist
      useradd -M -r --shell /sbin/nologin --home-dir $MYSQL_HOME_DIR --gid $MYSQL_GROUP $MYSQL_USER
   fi
   # Donwload, compile & install files:
   cd ~
   wget $MYSQL_URI #obtain precompiled binary files
   tar -zxf mysql*.tar.gz #unpack gzip archive
   mkdir -m u=rwx,g=rx,o=rx $MYSQL_HOME_DIR #create home directory
   cd mysql*
   mv --force --target-directory=$MYSQL_HOME_DIR * #move files to home directory
   # Create state directory:
   mkdir -m u=rwx,g=rwx,o= $MYSQL_STATE_DIR
   chown $MYSQL_USER $MYSQL_STATE_DIR
   # Create log directory:
   mkdir -m u=rwx,g=rwx,o= $MYSQL_LOG_DIR
   chown $MYSQL_USER $MYSQL_LOG_DIR
   # Make binaries availiable to PATH:
   PATH=$PATH:$MYSQL_HOME_DIR/bin
   export PATH
   echo -e "PATH=\$PATH:$MYSQL_HOME_DIR/bin\n\
export PATH" > /etc/profile.d/mysql.sh #make changes to PATH permanent for all users
   chmod u=rw,g=r,o=r /etc/profile.d/mysql.sh
   # Disable MySQL history log:
   MYSQL_HISTFILE=/dev/null
   export MYSQL_HISTFILE
   echo -e "MYSQL_HISTFILE=/dev/null\nexport MYSQL_HISTFILE\n" >> /etc/profile.d/mysql.sh #make changes to MYSQL_HISTFILE permanent for all users
   # Data folder must be owned by MySQL user + group
   chown --recursive $MYSQL_USER:$MYSQL_GROUP $MYSQL_HOME_DIR/data
   chmod o= $MYSQL_HOME_DIR/data
   # Plugin folder should not be writable by MySQL user:
   chown --recursive root:root $MYSQL_HOME_DIR/lib/plugin
   chmod o= $MYSQL_HOME_DIR/lib/plugin
   # Initialize grant tables and "test" databases:
   $MYSQL_HOME_DIR/scripts/mysql_install_db \
--basedir=$MYSQL_HOME_DIR \
--datadir=$MYSQL_HOME_DIR/data \
--user=$MYSQL_USER
   # Configure:
   echo -n \
"[client]
port=$port
socket=$MYSQL_STATE_DIR/mysql.sock

[mysqld]
user=$MYSQL_USER #run daemon under dedicated user account
port=$port
socket=$MYSQL_STATE_DIR/mysql.sock
basedir=$MYSQL_HOME_DIR
datadir=$MYSQL_HOME_DIR/data #set data directory
pid_file=$MYSQL_STATE_DIR/mysql.pid
log-error=$MYSQL_LOG_DIR/error.log
log-warnings=1 #print out warnings such as 'aborted connection' to the error log
slow-query-log=1
slow_query_log_file=$MYSQL_LOG_DIR/slow.log
skip-symbolic-links #do not permit the use of symlinks to tables
skip-name-resolve #do not resolve host names when checking client connections
skip-external-locking
safe-user-create=1 #a user cannot create new MySQL users using the GRANT statement unless she has INSERT privilege for mysql.user table
secure-auth=1 #disallow authentication by clients that attempt to use accounts that have old (pre-4.1) passwords
key_buffer_size = 256M
max_allowed_packet = 1M
table_open_cache = 256
sort_buffer_size = 1M
read_buffer_size = 1M
read_rnd_buffer_size = 4M
myisam_sort_buffer_size = 64M
thread_cache_size = 8
query_cache_size= 16M
thread_concurrency = 8 #set to (number of CPU's)*2
innodb_data_home_dir = /opt/mysql/data
innodb_data_file_path = ibdata1:10M:autoextend
innodb_log_group_home_dir = /opt/mysql/data
innodb_buffer_pool_size = 256M #set up to 50-80% of RAM
innodb_additional_mem_pool_size = 20M
innodb_log_file_size = 64M #set to 25% of innodb_buffer_pool_size
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 1
innodb_lock_wait_timeout = 50

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash
# Remove the next comment character if you are not familiar with SQL
#safe-updates

[myisamchk]
key_buffer_size = 128M
sort_buffer_size = 128M
read_buffer = 2M
write_buffer = 2M

[mysqlhotcopy]
interactive-timeout
" > /etc/my.cnf
   chmod u=rw,g=r,o= /etc/my.cnf
   # Set logs:
   touch $MYSQL_LOG_DIR/error.log #create error log
   chmod u=rw,g=rw,o= $MYSQL_LOG_DIR/error.log
   chown $MYSQL_USER $MYSQL_LOG_DIR/error.log
   touch $MYSQL_LOG_DIR/slow.log #create slow log
   chmod u=rw,g=rw,o= $MYSQL_LOG_DIR/slow.log
   chown $MYSQL_USER $MYSQL_LOG_DIR/slow.log
   # Integrate into logrotate:
   echo -n \
"$MYSQL_LOG_DIR/error.log {
   daily
   rotate 40
   extension log
   dateext
   dateformat %Y%m%d
   compress
   delaycompress
   missingok
   noolddir
   create 0640 $MYSQL_USER $MYSQL_GROUP
}

$MYSQL_LOG_DIR/slow.log {
   daily
   rotate 40
   extension log
   dateext
   dateformat %Y%m%d
   compress
   delaycompress
   missingok
   noolddir
   create 0640 $MYSQL_USER $MYSQL_GROUP
}" > /etc/logrotate.d/mysql
   chmod u=rw,g=r,o= /etc/logrotate.d/mysql
   # Set daemon:
   /bin/cp -rf $MYSQL_HOME_DIR/support-files/mysql.server /etc/init.d/mysqld #copy init.d script
   sed -i -e "s|^\(basedir\)\(\s\?=\s\?\)\(.*\)$|\1=$MYSQL_HOME_DIR|" /etc/init.d/mysqld #set installation home directory
   sed -i -e "s|^\(datadir\)\(\s\?=\s\?\)\(.*\)$|\1=$MYSQL_HOME_DIR/data|" /etc/init.d/mysqld #set data directory
   sed -i -e "s|^\(mysqld_pid_file_path\)\(\s\?=\s\?\)\(.*\)$|\1=$MYSQL_STATE_DIR/mysql.pid|" /etc/init.d/mysqld #set PID file
   chmod u=rwx,g=rx,o= /etc/init.d/mysqld #make executable
   chkconfig --add mysqld
   chkconfig --level 35 mysqld on
   service mysqld start #start daemon for the first time
   # Set firewall:
   allow_tcp $MYSQL_PORT
   # Collect garbage:
   cd ~
   rm -rf mysql*
   # Secure MySQL:
   sleep 10 #wait few seconds to make sure all processes are done
   mysql --user=root --execute="UPDATE mysql.user SET Password = PASSWORD('$password') WHERE User = 'root'; FLUSH PRIVILEGES;" #set password for root
   mysql --user=root --password="$password" --execute="DELETE FROM mysql.user WHERE User = '';" #delete anonymous users
   find /opt/mysql -type f -name ".empty" -exec rm -f {} \; #delete .empty files that appear out-of-nowhere and prevent mysql from deleting databases
   mysql --user=root --password="$password" --execute="DELETE FROM mysql.db WHERE Db LIKE 'test%'; DROP DATABASE test; FLUSH PRIVILEGES;" #delete test databases
}

# Uninstalls MySQL database server.
# Mysql server should be installed beforehand.
function uninstall_mysql {
   # Unset firewall:
   deny_tcp $MYSQL_PORT
   # Unset daemon:
   service mysqld stop #stop daemon
   chkconfig mysqld off
   chkconfig --del mysqld #remove from startup
   rm -f /etc/init.d/mysqld #delete init.d script
   # Unset logrotate configuration file:
   rm -f /etc/logrotate.d/mysql
   # Delete log directory:
   rm -rf $MYSQL_LOG_DIR
   # Delete run directory:
   rm -rf $MYSQL_STATE_DIR
   # Unset configuration file(s):
   rm -f /etc/my.cnf
   # Remove binaries from PATH:
   PATH=$(echo $PATH | sed -e "s|:$MYSQL_HOME_DIR/bin||")
   export PATH
   rm -f /etc/profile.d/mysql.sh
   # Delete installation files:
   rm -rf $MYSQL_HOME_DIR
   # Delete user & group:
   if ! grep -iq "^$MYSQL_USER" /etc/passwd ; then #user exists
      userdel --force --remove $MYSQL_USER
   fi
   if grep -iq "^$MYSQL_GROUP" /etc/group ; then #group exists
      groupdel $MYSQL_GROUP
   fi
   echo "MySQL server successfully uninstalled."
}

function set_mysql_master {
   #var=$(mysql --user=root --password="" --silent --skip-column-names --execute="SELECT INET_ATON('$(get_private_primary_ip)');")
}

function set_mysql_slave {
   #
}
