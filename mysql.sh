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

MYSQL_URI='http://dev.mysql.com/get/Downloads/MySQL-5.5/mysql-5.5.15-linux2.6-x86_64.tar.gz/from/http://www.mirrorservice.org/sites/ftp.mysql.com/'
MYSQL_USER='mysql'
MYSQL_GROUP='mysql'
MYSQL_HOME_DIR='/opt/mysql'
MYSQL_CONF_FILE='/etc/my.cnf'
MYSQL_LOG_DIR='/var/log/mysql'
MYSQL_STATE_DIR='/var/run/mysql'
MYSQL_PORT=${1-'3306'}
MYSQL_ROOT_USERNAME=${2-'root'}
MYSQL_ROOT_PASSWORD=${3-''}

# Installs MySQL relational database.
# Please refer to http://dev.mysql.com/doc/refman/5.5/en/server-logs.html for further study in MySQL Logs.
# Please refer to http://dev.mysql.com/doc/refman/5.5/en/security.html for further study in MySQL Security.
function install_mysql {
   # Create user & group:
   if ! grep -iq "^$MYSQL_GROUP" /etc/group ; then #group does not exist
      groupadd $MYSQL_GROUP
   fi
   if ! grep -iq "^$MYSQL_USER" /etc/passwd ; then #user does not exist
      useradd -M -r --shell /sbin/nologin --home-dir $MYSQL_HOME_DIR --gid $MYSQL_GROUP $MYSQL_USER
   fi
   # Create directories & set appropriate permissions:
   mkdir -m u=rwx,g=rx,o=rx $MYSQL_HOME_DIR
   mkdir -m u=rwx,g=rwx,o= $MYSQL_LOG_DIR
   chown $MYSQL_USER $MYSQL_LOG_DIR
   mkdir -m u=rwx,g=rwx,o= $MYSQL_STATE_DIR
   chown $MYSQL_USER $MYSQL_STATE_DIR   
   # Donwload, compile & install files:
   cd ~
   wget $MYSQL_URI #obtain precompiled binary files
   tar -zxf mysql*.tar.gz #unpack gzip archive
   cd mysql*
   mv --force --target-directory=$MYSQL_HOME_DIR * #move files to home directory
   # Data folder must be owned by MySQL user
   chown --recursive $MYSQL_USER $MYSQL_HOME_DIR/data
   chmod u=rwx,g=rx,o= $MYSQL_HOME_DIR/data
   # Plugin folder should not be writable by MySQL user:
   chown --recursive root:root $MYSQL_HOME_DIR/lib/plugin
   chmod u=rwx,g=rx,o= $MYSQL_HOME_DIR/lib/plugin
   # Make binaries availiable to PATH:
   PATH=$PATH:$MYSQL_HOME_DIR/bin
   export PATH
   echo -n \
"PATH=\$PATH:$MYSQL_HOME_DIR/bin
export PATH
" > /etc/profile.d/mysql.sh #make changes permanent for all users
   chmod u=rw,g=r,o=r /etc/profile.d/mysql.sh
   # Disable MySQL history log:
   MYSQL_HISTFILE=/dev/null
   export MYSQL_HISTFILE
   echo -n \
"MYSQL_HISTFILE=/dev/null
export MYSQL_HISTFILE
" >> /etc/profile.d/mysql.sh #make changes permanent for all users
   # Initialize grant tables and "test" databases:
   $MYSQL_HOME_DIR/scripts/mysql_install_db \
--basedir=$MYSQL_HOME_DIR \
--datadir=$MYSQL_HOME_DIR/data \
--user=$MYSQL_USER
   # Configure:
   echo -n \
"[client]
port=$MYSQL_PORT
socket=$MYSQL_STATE_DIR/mysql.sock

[mysqld]
user=$MYSQL_USER #run daemon under dedicated user account
port=$MYSQL_PORT
socket=$MYSQL_STATE_DIR/mysql.sock
basedir=$MYSQL_HOME_DIR
datadir=$MYSQL_HOME_DIR/data #set data directory
pid_file=$MYSQL_STATE_DIR/mysql.pid #set PID file
# LOG SETTINGS:
log-output=FILE #output general & slow query logs to files
general-log=1 #enable general query logging
general_log_file=$MYSQL_LOG_DIR/mysql.log #specify general query log file
slow-query-log=1 #enable slow query logging
long_query_time=10 #after 10 secs query is considered as slow
slow_query_log_file=$MYSQL_LOG_DIR/slow.log #specify slow query log file
log-error=$MYSQL_LOG_DIR/error.log #set error log file
log-warnings=1 #print out warnings, such as 'aborted connection', to the error log
# SECURITY SETTINGS:
skip-symbolic-links #do not permit the use of symlinks to tables
skip-name-resolve #do not resolve host names when checking client connections
skip-external-locking
safe-user-create=1 #a user cannot create new MySQL users using the GRANT statement unless she has INSERT privilege for mysql.user table
secure-auth=1 #disallow authentication by clients that attempt to use accounts that have old (pre-4.1) passwords
# ENGINE SETTINGS:
key_buffer_size=256M
max_allowed_packet=1M
table_open_cache=256
sort_buffer_size=1M
read_buffer_size=1M
read_rnd_buffer_size=4M
myisam_sort_buffer_size=64M
thread_cache_size=8
query_cache_size=16M
thread_concurrency=8 #set to (number of CPU's)*2
innodb_data_home_dir=/opt/mysql/data
innodb_data_file_path=ibdata1:10M:autoextend
innodb_log_group_home_dir=/opt/mysql/data
innodb_buffer_pool_size=256M #set up to 50-80% of RAM
innodb_additional_mem_pool_size=20M
innodb_log_file_size=64M #set to 25% of innodb_buffer_pool_size
innodb_log_buffer_size=8M
innodb_flush_log_at_trx_commit=1 #important for binary logging
innodb_lock_wait_timeout=50
# REPLICATION SETTINGS:
#server-id=0
#log-bin=mysql-bin
#binlog-format=format=MIXED
#max_binlog_size=1073741824
#expire_logs_days=7
#sync_binlog=1

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
" > $MYSQL_CONF_FILE
   chmod u=rw,g=r,o= $MYSQL_CONF_FILE
   # Set logs:
   touch $MYSQL_LOG_DIR/error.log #create error log
   chmod u=rw,g=rw,o= $MYSQL_LOG_DIR/error.log
   chown $MYSQL_USER $MYSQL_LOG_DIR/error.log
   touch $MYSQL_LOG_DIR/slow.log #create slow log
   chmod u=rw,g=rw,o= $MYSQL_LOG_DIR/slow.log
   chown $MYSQL_USER $MYSQL_LOG_DIR/slow.log
   # Integrate into logrotate:
   echo -n \
"$MYSQL_LOG_DIR/mysql.log {
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

$MYSQL_LOG_DIR/error.log {
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
   sed -i -e "s|^\(basedir\)\(\s\?=\s\?\)\(.*\)$|\1='$MYSQL_HOME_DIR'|" /etc/init.d/mysqld #set installation home directory
   sed -i -e "s|^\(datadir\)\(\s\?=\s\?\)\(.*\)$|\1='$MYSQL_HOME_DIR/data'|" /etc/init.d/mysqld #set data directory
   sed -i -e "s|^\(lockdir\)\(\s\?=\s\?\)\(.*\)$|\1='$MYSQL_STATE_DIR'|" /etc/init.d/mysqld #set lock directory
   sed -i -e "s|^\(lock_file_path\)\(\s\?=\s\?\)\(.*\)$|\1=\"\$lockdir/mysql.lock\"|" /etc/init.d/mysqld #set lock file
   sed -i -e "s|^\(mysqld_pid_file_path\)\(\s\?=\s\?\)\(.*\)$|\1='$MYSQL_STATE_DIR/mysql.pid'|" /etc/init.d/mysqld #set PID file
   chmod u=rwx,g=rx,o= /etc/init.d/mysqld #make executable
   chkconfig --add mysqld
   chkconfig --level 35 mysqld on
   service mysqld start #start daemon for the first time
   # Set firewall:
   allow tcp $MYSQL_PORT
   # Collect garbage:
   cd ~
   rm -rf mysql*
   # Secure MySQL:
   sleep 10 #wait few seconds to make sure all processes are done
   mysql --user=root --execute=\
"UPDATE mysql.user SET User='$MYSQL_ROOT_USERNAME', Password=PASSWORD('$MYSQL_ROOT_PASSWORD') WHERE User = 'root'; #change root username + set new password
FLUSH PRIVILEGES;"
   mysql --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD" --execute=\
"DELETE FROM mysql.user WHERE User=''; #delete anonymous users
DELETE FROM mysql.user WHERE Host='%'; #delete any user @ external hosts
FLUSH PRIVILEGES;"
   find /opt/mysql -type f -name ".empty" -exec rm -f {} \; #delete .empty files that appear out-of-nowhere and prevent mysql from deleting databases
   mysql --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD" --execute=\
"DELETE FROM mysql.db WHERE Db LIKE 'test%'; #delete test databases
DROP DATABASE test;
FLUSH PRIVILEGES;"
}

# Uninstalls MySQL database server.
# MySQL server should be installed beforehand.
function uninstall_mysql {
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 0 #exit      
   fi
   # Unset firewall:
   deny tcp $MYSQL_PORT
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
   rm -f $MYSQL_CONF_FILE
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

# Creates new user account in MySQL.
# Please refer to http://dev.mysql.com/doc/refman/5.5/en/account-management-sql.html for further study in MySQL account management.
# MySQL server should be installed beforehand.
# $1 the name of the user that will be created, i.e. 'annie'. {REQUIRED}
# $2 the password of the user account to-be-created. {REQUIRED}
function create_mysql_user {
   local username="$1"
   local password="$2"
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 0 #exit      
   fi
   # Make sure username is specified:
   if [ -z $username ] ; then #username not specified
      echo "Account username must be specified."
      return 0 #exit
   fi
   # Make sure password is specified:
   if [ -z $password ] ; then #password not specified
      echo "Account password must be specified."
      return 0 #exit
   fi
   # Create account:
   mysql --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD" --execute=\
"CREATE USER '$username' IDENTIFIED BY '$password';
FLUSH PRIVILEGES;"
}

# Please refer to http://dev.mysql.com/doc/refman/5.5/en/account-management-sql.html for further study in MySQL account management.
# MySQL server should be installed beforehand.
function remove_mysql_user {
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 0 #exit      
   fi
   echo "Under Construction!"
}

# MySQL server should be installed beforehand.
function add_mysql_db {
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 0 #exit      
   fi
   echo "Under Construction!"
}

# MySQL server should be installed beforehand.
function remove_mysql_db {
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 0 #exit      
   fi
   echo "Under Construction!"
}

# Sets locally installed MySQL server as master.
# Please refer to http://dev.mysql.com/doc/refman/5.5/en/replication.html for further study in MySQL Replication.
# MySQL server should be installed beforehand.
# $1 server id number, ranges between 1 and 4294967295, defaults to INET_ATON(Private IP address). {OPTIONAL}
function set_mysql_master {
   local server_id="$1"
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 0 #exit      
   fi
   # Determine server unique id number:
   if [ -z $server_id ] ; then #server id not specified
      server_id=$(mysql --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD" --silent --skip-column-names --execute=\
"SELECT INET_ATON('$(get_private_primary_ip)');") #convert internal IP address to number using MySQL INET_ATON function
      if [ -z $server_id ] ; then #server id still invalid
         echo "Server id could not be determined. Please specify a number between 1 and 4294967295."
         return 0 #exit
      fi
   fi
   # Configure MySQL as master:
   sed -i -e "s|^#\?\(server-id\).*$|\1=$server_id|" $MYSQL_CONF_FILE #set unique server id
   sed -i -e "s|^#\?\(log-bin\).*$|\1=mysql-bin|" $MYSQL_CONF_FILE #set the base-name of binary logs (extensions such as .log do not apply)
   sed -i -e "s|^#\?\(binlog-format\).*$|\1=MIXED|" $MYSQL_CONF_FILE #set binlog format to MIXED
   sed -i -e "s|^#\?\(max_binlog_size\).*$|\1=1073741824|" $MYSQL_CONF_FILE #set max binlog size to 1GB
   sed -i -e "s|^#\?\(expire_logs_days\).*$|\1=7|" $MYSQL_CONF_FILE #delete binlogs older than 7 days
   sed -i -e "s|^#\?\(sync_binlog\).*$|\1=1|" $MYSQL_CONF_FILE #safest choice in the event of a crash for innodb transactions
   echo "MySQL server $server_id is set as master replica." #echo success message
   service mysqld restart #restart server
}

# Sets locally installed MySQL server as master.
# Please refer to http://dev.mysql.com/doc/refman/5.5/en/replication.html for further study in MySQL Replication.
# MySQL server should be installed beforehand.
# $2 server id number, ranges between 1 and 4294967295, defaults to INET_ATON(Private IP address). {OPTIONAL}
function set_mysql_slave {
   local server_id="$1"
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 0 #exit      
   fi
   # Determine server unique id number:
   if [ -z $server_id ] ; then #server id not specified
      server_id=$(mysql --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD" --silent --skip-column-names --execute=\
"SELECT INET_ATON('$(get_private_primary_ip)');") #convert internal IP address to number using MySQL INET_ATON function
      if [ -z $server_id ] ; then #server id still invalid
         echo "Server id could not be determined. Please specify a number between 1 and 4294967295."
         return 0 #exit
      fi
   fi
   # Configure MySQL as slave:
   sed -i -e "s|^#\?\(server-id\).*$|\1=$server_id|" $MYSQL_CONF_FILE #set unique server id
}
