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

GLUSTER_URI='http://download.gluster.com/pub/gluster/glusterfs/LATEST/glusterfs-3.2.3.tar.gz'
GLUSTER_USER='mysql'
GLUSTER_GROUP='mysql'
GLUSTER_HOME_DIR='/opt/gluster'
GLUSTER_CONF_FILE='/etc/my.cnf'
GLUSTER_LOG_DIR='/var/log/gluster'
GLUSTER_STATE_DIR='/var/run/mysql'

# Installs gluster infrastructure for running both daemon and client instances.
function gluster.install {
   # Create directories & set appropriate permissions:
   mkdir -m u=rwx,g=rx,o=rx $GLUSTER_HOME_DIR
   mkdir -m u=rwx,g=rwx,o= $GLUSTER_LOG_DIR
   # Install prerequisites:
   yum -y install bison gcc portmap flex libtool fuse make automake autoconf
   # Download, compile & install files:
   cd ~
   wget $GLUSTER_URI #obtain source code
   tar -zxf gluster*.tar.gz #unpack gzip archive
   cd gluster*
   # Georeplication module is not needed because we won't be creating volumes geographically dispersed.
   # Infiniband module is not needed because we won't be using infiniband network protocol.
   ./configure --prefix=$GLUSTER_HOME_DIR \
--with-initdir=/etc/init.d \
--disable-georeplication \
--disable-infiniband
   make #compile
   make install #install
   # Make binaries availiable to PATH:
   PATH=$PATH:$GLUSTER_HOME_DIR/sbin
   export PATH
   echo -e "PATH=\$PATH:$GLUSTER_HOME_DIR/sbin\n\
export PATH" > /etc/profile.d/gluster.sh #make changes to PATH permanent for all users
   chmod u=rw,g=r,o=r /etc/profile.d/gluster.sh
   # Collect garbage
   cd ~
   rm -rf gluster*
   return 0 #done
}

# Sets gluster daemon.
function gluster.set_daemon {
   # Make sure Gluster is installed:
   if [ ! -e $GLUSTER_HOME_DIR/sbin/gluster ] ; then
      echo "Gluster not found on this system. Please install Gluster and retry."
      return 1 #exit      
   fi
   # Set daemon:
   chmod u=rwx,g=rx,o= /etc/init.d/glusterd #make executable
   chkconfig --add glusterd
   chkconfig --level 35 glusterd on
   service glusterd start #start daemon for the first time
   # Set firewall:
   # Allow UDP & TCP 111 for port-mapper service.
   # Allow TCP 24007 & 24008 by default, in all gluster daemon nodes.
   # Allow additional ports up to 24008+n, where n resembles the number of bricks per volume.
   # In this case, just one brick per volume is needed. Thus only port 24009 should be opened.
   firewall.allow udp 111
   firewall.allow tcp 111 24007 24008 24009
   return 0 #done
}

# Creates a new gluster volume.
# $1 the name of the volume, i.e. 'athos'. {REQUIRED}
# $2 the path of the actual folder that will be shared across nodes, i.e. '/etc/athos'. {REQUIRED}
function gluster.create_volume {
   local volume="$1"
   local path="$2"
   # Make sure Gluster is installed:
   if [ ! -e $GLUSTER_HOME_DIR/sbin/gluster ] ; then
      echo "Gluster not found on this system. Please install Gluster and retry."
      return 1 #exit      
   fi
   # Make sure volume name is specified:
   if [ -z $volume ] ; then #volume not specified
      echo "Volume name must be specified."
      return 1 #exit
   fi
   # Make sure path is specified:
   if [ -z $path ] ; then #path not specified
      echo "The path of the actual folder that will be shared across nodes must be specified."
      return 1 #exit
   fi
   # Make sure path is valid:
   if [ ! -d $path ] ; then #path not valid
      echo "The specified path refers to a directory that does not exist."
      return 1 #exit
   fi
   # Create volume:
   gluster volume create $volume transport tcp $(network.get_ip)":"$path #create volume and add first brick
   gluster volume info #display volume info
   gluster volume log filename $volume $GLUSTER_LOG_DIR #set logs
   gluster volume log locate $volume #display logs info
   gluster volume log rotate $volume #rotate logs
   gluster volume start $volume #start volume - yeah baby
   return 0 #done
}

# Expands the specified gluster volume.
# Should be run on the first node of the volume.
# $1 hostname or ip address of the gluster expansion server. {REQUIRED}
# $2 the name of the volume, i.e. data. {REQUIRED}
# $3 the path of the actual folder that will be shared across nodes, i.e. /etc/data. {REQUIRED}
function gluster.expand_volume {
   local host="$1"
   local volume="$2"
   local path="$3"
   # Make sure Gluster is installed:
   if [ ! -e $GLUSTER_HOME_DIR/sbin/gluster ] ; then
      echo "Gluster not found on this system. Please install Gluster and retry."
      return 1 #exit      
   fi
   # Make sure host is specified:
   if [ -z $host ] ; then #host not specified
      echo "Hostname or IP address must be specified."
      return 1 #exit
   fi
   # Make sure volume is specified:
   if [ -z $volume ] ; then #volume not specified
      echo "Volume name must be specified."
      return 1 #exit
   fi
   # Make sure path is specified:
   if [ -z $path ] ; then #path not specified
      echo "The path of the actual folder that will be shared across nodes must be specified."
      return 1 #exit
   fi
   # Make sure path is valid:
   if [ ! -d $path ] ; then #path not valid
      echo "The specified path refers to a directory that does not exist."
      return 1 #exit
   fi
   # Expand volume:
   gluster peer probe $host #probe new host
   gluster volume add-brick $volume $host":"$path #add new brick to volume
   gluster volume info #display volume info
   gluster volume rebalance $volume start #rebalance the data among the bricks (process execution continues in the background)
   return 0 #done
}

# Mounts the specified volume to the supplied path.
# $1 hostname or ip address of the volume's primary server. {REQUIRED}
# $2 the name of the volume. {REQUIRED}
# $3 the path of the mount point for the local machine. {REQUIRED}
function gluster.mount_volume {
   local host="$1"
   local volume="$2"
   local path="$3"
   # Make sure Gluster is installed:
   if [ ! -e $GLUSTER_HOME_DIR/sbin/gluster ] ; then
      echo "Gluster not found on this system. Please install Gluster and retry."
      return 1 #exit      
   fi
   # Make sure host is specified:
   if [ -z $host ] ; then #host not specified
      echo "Hostname or IP address must be specified."
      return 1 #exit
   fi
   # Make sure volume is specified:
   if [ -z $volume ] ; then #volume not specified
      echo "Volume name must be specified."
      return 1 #exit
   fi
   # Make sure path is specified:
   if [ -z $path ] ; then #path not specified
      echo "The path of the mount point must be specified."
      return 1 #exit
   fi
   # Mount volume:
   mkdir $path #create the mount point
   if mount|grep $path; then umount $path; fi #make sure that mount point is not already in use
   echo -e "$host:/$volume $path glusterfs defaults,_netdev,log-level=WARNING,log-file=$GLUSTER_LOG_DIR/mount.log,transport=tcp,acl 0 0" >> /etc/fstab
   mount $path
   return 0 #done
}
