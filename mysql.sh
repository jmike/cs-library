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
MYSQL_LOCK_DIR='/var/lock/mysql'
MYSQL_PORT=${1-'3306'}
MYSQL_ROOT_USERNAME=${2-'root'}
MYSQL_ROOT_PASSWORD=${3-''}

# Installs MySQL database server.
# Refer to http://dev.mysql.com/doc/refman/5.5/en/server-logs.html for further study in MySQL Logs.
# Refer to http://dev.mysql.com/doc/refman/5.5/en/security.html for further study in MySQL Security.
function mysql.install {
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
   mkdir -m u=rwx,g=rwx,o= $MYSQL_LOCK_DIR
   chown $MYSQL_USER $MYSQL_LOCK_DIR  
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
#log-bin-index=mysql-bin.index
#binlog-format=format=MIXED
#max_binlog_size=1073741824
#sync_binlog=1
#expire_logs_days=7
#relay-log=relay-bin 
#max_relay_log_size=1073741824
#relay-log-index=relay-bin.index
#relay-log-info-file=relay-log.info
#sync_relay_log=1
#relay-log-recovery=1
#relay_log_purge=1

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
   sed -i -e "s|^\(lockdir\)\(\s\?=\s\?\)\(.*\)$|\1='$MYSQL_LOCK_DIR'|" /etc/init.d/mysqld #set lock directory
   sed -i -e "s|^\(lock_file_path\)\(\s\?=\s\?\)\(.*\)$|\1=\"\$lockdir/mysql.lock\"|" /etc/init.d/mysqld #set lock file
   sed -i -e "s|^\(mysqld_pid_file_path\)\(\s\?=\s\?\)\(.*\)$|\1='$MYSQL_STATE_DIR/mysql.pid'|" /etc/init.d/mysqld #set PID file
   chmod u=rwx,g=rx,o= /etc/init.d/mysqld #make executable
   chkconfig --add mysqld
   chkconfig --level 35 mysqld on
   service mysqld start #start daemon for the first time
   # Set firewall:
   firewall.allow tcp $MYSQL_PORT
   # Collect garbage:
   cd ~
   rm -rf mysql*
   # Secure MySQL:
   sleep 10 #wait few seconds to make sure all processes are done
   mysql --user=root --execute=\
"UPDATE mysql.user SET User='$MYSQL_ROOT_USERNAME', Password=PASSWORD('$MYSQL_ROOT_PASSWORD') WHERE User='root'; #change root username + set new password
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
   return 0 #done
}

# Uninstalls local MySQL server.
function mysql.uninstall {
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 1 #exit      
   fi
   # Unset firewall:
   firewall.deny tcp $MYSQL_PORT
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
   return 0 #done
}

# Return 0 if user account exists in local MySQL server, 1 if not.
# $1 the name of the user, i.e. 'billy'. {REQUIRED}
function mysql.exists_user {
   local name="$1"
   # Make sure name is specified:
   if [ -z $name ] ; then #name not specified
      echo "User's name must be specified."
      return 1 #exit
   fi
   # Check if user exists:
   local exists=$(mysql --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD" --silent --skip-column-names --execute=\
"SELECT COUNT(*) FROM mysql.user WHERE User='$name';")
   if [ -z $exists -o $exists -eq 0 ] ; then #user not found
      return 1
   fi
   return 0
}

# Creates new user account in MySQL server.
# Refer to http://dev.mysql.com/doc/refman/5.5/en/account-management-sql.html for further study in MySQL account management.
# $1 the name of the user that will be created, i.e. 'annie'. {REQUIRED}
# $2 the password of the user account to-be-created. {REQUIRED}
function mysql.create_user {
   local name="$1"
   local password="$2"
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 1 #exit
   fi
   # Make sure name is specified:
   if [ -z $name ] ; then #name not specified
      echo "User's name must be specified."
      return 1 #exit
   fi
   # Make sure password is specified:
   if [ -z $password ] ; then #password not specified
      echo "User's password must be specified."
      return 1 #exit
   fi
   # Make sure user does not exist:
   if mysql.exists_user $name ; then
      echo "Username \"$name\" is already taken. Please specify another name."
      return 1 #exit
   fi
   # Create user account:
   mysql --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD" --execute=\
"CREATE USER '$name' IDENTIFIED BY '$password';
FLUSH PRIVILEGES;"
   echo "User \"$name\" created successfully." #echo success message
   return 0 #done
}

# Deletes the specified user account from MySQL server.
# Refer to http://dev.mysql.com/doc/refman/5.5/en/account-management-sql.html for further study in MySQL account management.
# $1 the name of the user that will be deleted, i.e. 'fergie'. {REQUIRED}
function mysql.delete_user {
   local name="$1"
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 1 #exit      
   fi
   # Make sure name is specified:
   if [ -z $name ] ; then #name not specified
      echo "User's name must be specified."
      return 1 #exit
   fi
   # Make sure user exists:
   if ! mysql.exists_user $name ; then
      echo "User \"$name\" does not exist. Please specify a valid user."
      return 1 #exit
   fi
   # Delete user account:
   mysql --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD" --execute=\
"DROP USER '$name';
FLUSH PRIVILEGES;"
   echo "User \"$name\" successfully deleted." #echo success message
   return 0 #done
}

# Returns 0 if the specified MySQL database name is valid, 1 if not.
# Refer to http://dev.mysql.com/doc/refman/5.5/en/identifiers.html for valid database names.
# $1 the name of the database. {REQUIRED}
function mysql.valid_db_name {
   local db_name="$1"
   if [[ $db_name =~ ^[0-9,a-z,A-Z_$]+$ ]] ; then #db name is valid
      return 0
   else #db name is invalid
      return 1
   fi
}

# Creates a database with the specified name in MySQL server.
# $1 the name of the database, i.e. 'wordpress'. {REQUIRED}
function mysql.create_db {
   local db_name="$1"
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 1 #exit      
   fi
   # Make sure db_name is specified:
   if [ -z $db_name ] ; then #db name not specified
      echo "The name of the database must be specified."
      return 1 #exit
   fi
   # Make sure db_name is valid:
   if mysql.valid_db_name $db_name ; then
      echo "The name of the database is invalid."
      return 1 #exit      
   fi
   # Create database:
   mysql --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD" --execute=\
"CREATE DATABASE IF NOT EXISTS $db_name DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;"
   echo "Database \"$db_name\" successfully created." #echo success message
   return 0 #done
}

# Deletes the specified database from MySQL server.
# $1 the name of the database, i.e. 'wordpress'. {REQUIRED}
function mysql.delete_db {
   local db_name="$1"
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 1 #exit      
   fi
   # Make sure db_name is specified:
   if [ -z $db_name ] ; then #db name not specified
      echo "The name of the database must be specified."
      return 1 #exit
   fi
   # Make sure db_name is valid:
   if mysql.valid_db_name $db_name ; then
      echo "The name of the database is invalid."
      return 1 #exit      
   fi
   # Delete database:
   mysql --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD" --execute=\
"DROP DATABASE IF NOT EXISTS $db_name;"
   echo "Database \"$db_name\" successfully deleted." #echo success message
   return 0 #done
}

# Grants all priviledges to the specified user for administering the supplied database.
# $1 the user that will be granted the priviledges, i.e. 'jason'. {REQUIRED}
# $2 the name of the database upon which the priviledges apply, i.e. 'wordpress'. {REQUIRED}
function mysql.grant_db_priv {
   local user="$1"
   local db_name="$2"
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 1 #exit      
   fi
   # Make sure user is specified:
   if [ -z $user ] ; then #user not specified
      echo "User's name must be specified."
      return 1 #exit
   fi
   # Make sure user exists:
   if ! mysql.exists_user $user ; then
      echo "User \"$user\" does not exist. Please specify a valid user."
      return 1 #exit
   fi
   # Make sure db_name is specified:
   if [ -z $db_name ] ; then #db name not specified
      echo "The name of the database must be specified."
      return 1 #exit
   fi
   # Make sure db_name is valid:
   if mysql.valid_db_name $db_name ; then
      echo "The name of the database is invalid."
      return 1 #exit      
   fi
   # Grant priviledge(s):
   mysql --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD" --execute=\
"GRANT ALL PRIVILEGES ON `$db_name`.* TO '$user'@'%';
FLUSH PRIVILEGES;"
   echo "User \"$user\" granted with all priviledges for \"$db_name\" database." #echo success message
   return 0 #done
}

# Grants the REPLICATION SLAVE priviledge to the specified MySQL user.
# Priviledge is applied to all TABLES, FUNCTIONS and PROCEDURES.
# $1 the user that will be granted the priviledge, i.e. 'thalia'. {REQUIRED}
function mysql.grant_replication_priv {
   local user="$1"
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 1 #exit      
   fi
   # Make sure user is specified:
   if [ -z $user ] ; then #user not specified
      echo "User's name must be specified."
      return 1 #exit
   fi
   # Make sure user exists:
   if ! mysql.exists_user $user ; then
      echo "User \"$user\" does not exist. Please specify a valid user."
      return 1 #exit
   fi
   # Grant priviledge(s):
   mysql --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD" --execute=\
"GRANT REPLICATION SLAVE ON *.* TO '$user'@'%';
FLUSH PRIVILEGES;"
   echo "User \"$user\" granted with REPLICATION SLAVE priviledge." #echo success message
   return 0 #done
}

# Delivers a unique server id by converting internal IP address to number (using MySQL INET_ATON function).
function mysql.deliver_server_id {
   echo $(mysql --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD" --silent --skip-column-names --execute=\
"SELECT INET_ATON('$(network.get_ip eth0:1)');")
   return 0 #done
}

# Sets local MySQL server as master node.
# Refer to http://dev.mysql.com/doc/refman/5.5/en/replication.html for further study in MySQL Replication.
# $1 server id number, ranges between 1 and 4294967295, defaults to INET_ATON(Private IP address). {OPTIONAL}
function mysql.set_master {
   local server_id=${1-$(mysql.deliver_server_id)}
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 1 #exit      
   fi
   # Make sure server id is valid:
   if [ -z $server_id ] ; then #server id not valid
      echo "Invalid server id. Please specify a number between 1 and 4294967295."
      return 1 #exit
   fi
   # Configure MySQL as master:
   sed -i -e "s|^#\?\(server-id\).*$|\1=$server_id|" $MYSQL_CONF_FILE #set unique server id
   sed -i -e "s|^#\?\(log-bin\).*$|\1=$MYSQL_LOG_DIRECTORY/mysql-bin|" $MYSQL_CONF_FILE #set the base-name of binary logs (extensions such as .log do not apply)
   sed -i -e "s|^#\?\(log-bin-index\).*$|\1=$MYSQL_LOG_DIRECTORY/mysql-bin.index|" $MYSQL_CONF_FILE #set the base-name of binary logs index
   sed -i -e "s|^#\?\(binlog-format\).*$|\1=MIXED|" $MYSQL_CONF_FILE #set binlog format to MIXED
   sed -i -e "s|^#\?\(max_binlog_size\).*$|\1=1073741824|" $MYSQL_CONF_FILE #set max binlog size to 1GB
   sed -i -e "s|^#\?\(expire_logs_days\).*$|\1=7|" $MYSQL_CONF_FILE #delete binlogs older than 7 days
   sed -i -e "s|^#\?\(sync_binlog\).*$|\1=1|" $MYSQL_CONF_FILE #safest choice in the event of a crash for innodb transactions
   service mysqld restart #restart server
   echo "MySQL server $server_id successfully set as master." #echo success message
   return 0 #done
}

# Creates a snapshot of data for the local MySQL server.
# The snapshot file is stored under the specified directory. 
# Gunzip compression algorithm is applied, thus the final output is named 'snapshot.sql.gz'.
# The snapshot file includes 'CHANGE MASTER TO' statement that indicates the binary log coordinates (file name and position) of the master node.
# Most likely a 'CHANGE MASTER TO' statement must be re-issued when data is loaded into slave, in order to specify MASTER_HOST, MASTER_USER and MASTER_PASSWORD values.
# Refer to http://dev.mysql.com/doc/refman/5.5/en/replication-howto-mysqldump.html for further study into exporting MySQL data snapshots.
# $1 the directory, where data will be stored, defaults to '~'. {OPTIONAL}
function mysql.export_data {
   local export_dir=${1,'~'}
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 1 #exit      
   fi
   # Export data:
   mysqldump --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD" --all-databases --master-data | gzip > $export_dir/snapshot.sql.gz
   return 0 #done
}

# Sets local MySQL server as slave to the specified master node.
# Refer to http://dev.mysql.com/doc/refman/5.5/en/replication.html for further study in MySQL Replication.
# $1 the hostname or IP address of the master, i.e. '195.168.2.3'. {REQUIRED}
# $2 the port number of the master, i.e. '3306'. {REQUIRED}
# $3 the MySQL user, with whom the slave connects to the master, i.e. 'annie'. {REQUIRED}
# $4 the password of the MySQL user, with whom the slave connects to the master. {REQUIRED}
# Please note that user must be in existence (on the master node) and granted with the REPLICATION SLAVE priviledge.
# $5 the path to the snapshot file that contains data and 'CHANGE MASTER TO' statement, exported from the master. {REQUIRED}
# $6 the server id number of the slave, ranges between 1 and 4294967295, defaults to INET_ATON(Private IP address). {OPTIONAL}
function mysql.set_slave {
   local master_host="$1"
   local master_port="$2"
   local master_user="$3"
   local master_password="$4"
   local data_file="$5"
   local server_id=${6-$(mysql.deliver_server_id)}
   # Make sure MySQL is installed:
   if [ ! -e $MYSQL_HOME_DIR/bin/mysql ] ; then
      echo "MySQL server not found on this system. Please install MySQL and retry."
      return 1 #exit      
   fi
   # Make sure master's host is specified:
   if [ -z $master_host ] ; then #master's host not specified
      echo "The host or IP address of the master must be specified."
      return 1 #exit
   fi
   # Make sure master's port is specified:
   if [ -z $master_port ] ; then #master's port not specified
      echo "The port number of the master must be specified."
      return 1 #exit
   fi
   # Make sure master's port is valid:
   if ! network.valid_port $master_port ; then
      echo "Invalid master's port $port. Please specify a number between 0 and 65535."
      return 1 #exit
   fi
   # Make sure master's user is specified:
   if [ -z $master_user ] ; then #user not specified
      echo "MySQL user to connect to the master must be specified."
      return 1 #exit
   fi
   # Make sure the password of master's user is specified:
   if [ -z $master_password ] ; then #password not specified
      echo "Password for MySQL user must be specified."
      return 1 #exit
   fi
   # Make sure data file exists:
   if [ -e $data_file ] ; then #data file not found
      echo "Snapshot file with master data cannot be found."
      return 1 #exit
   fi
   # Make sure server id is valid:
   if [ -z $server_id ] ; then #server id not valid
      echo "Invalid server id. Please specify a number between 1 and 4294967295."
      return 1 #exit
   fi
   # Configure MySQL as slave:
   sed -i -e "s|^#\?\(server-id\).*$|\1=$server_id|" $MYSQL_CONF_FILE #set unique server id
   sed -i -e "s|^#\?\(relay-log\).*$|\1=$MYSQL_LOG_DIR/relay-bin|" $MYSQL_CONF_FILE
   sed -i -e "s|^#\?\(relay-log-index\).*$|\1=$MYSQL_LOG_DIR/relay-bin.index|" $MYSQL_CONF_FILE
   sed -i -e "s|^#\?\(relay-log-info-file\).*$|\1=$MYSQL_LOG_DIR/relay-log.info|" $MYSQL_CONF_FILE
   sed -i -e "s|^#\?\(max_relay_log_size\).*$|\1=1073741824|" $MYSQL_CONF_FILE
   sed -i -e "s|^#\?\(sync_relay_log\).*$|\1=1|" $MYSQL_CONF_FILE
   sed -i -e "s|^#\?\(relay-log-recovery\).*$|\1=1|" $MYSQL_CONF_FILE
   sed -i -e "s|^#\?\(relay_log_purge\).*$|\1=1|" $MYSQL_CONF_FILE
   service mysqld restart #restart server
   # Import data from master + set MASTER_LOG_FILE and MASTER_LOG_POS:
   zcat $data_file | mysql --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD"
   # Set MASTER_HOST, MASTER_USER, MASTER_PASSWORD, etc:
   mysql --user=$MYSQL_ROOT_USERNAME --password="$MYSQL_ROOT_PASSWORD" --execute=\
"STOP SLAVE;
CHANGE MASTER TO
   MASTER_HOST='$master_host', 
   MASTER_PORT=$master_port, 
   MASTER_USER='$master_user', 
   MASTER_PASSWORD='$master_password', 
   MASTER_CONNECT_RETRY=30;
START SLAVE;
SHOW SLAVE STATUS;"
   return 0 #done
}
