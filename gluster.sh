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

# Installs gluster infrastructure for running both daemon and client.
# $1 URI of gluster source code in tar.gz format
function install_gluster {
   local uri=${1-"http://download.gluster.com/pub/gluster/glusterfs/LATEST/glusterfs-3.2.3.tar.gz"}
   local home="/opt/gluster"
   # Install prerequisites:
   yum -y install bison gcc portmap flex libtool fuse make automake autoconf
   # Download, compile & install files:
   cd ~
   wget $uri #obtain source code
   tar -zxf gluster*.tar.gz #unpack gzip archive
   cd gluster*
   # Georeplication module is not needed because we won't be creating volumes geographically dispersed.
   # Infiniband module is not needed because we won't be using infiniband network protocol.
   ./configure --prefix=$home \
--with-initdir=/etc/init.d \
--disable-georeplication \
--disable-infiniband
   make #compile
   make install #install
   # Make binaries availiable to PATH:
   PATH=$PATH:$home/sbin
   export PATH
   echo -e "PATH=\$PATH:$home/sbin\n\
export PATH" > /etc/profile.d/gluster.sh #make changes to PATH permanent for all users
   chmod u=rw,g=r,o=r /etc/profile.d/gluster.sh
   # Collect garbage
   cd ~
   rm -rf gluster*
}

# Sets gluster daemon.
# Gluster should be installed beforehand.
function set_glusterd {
   chmod u=rwx,g=rx,o= /etc/init.d/glusterd #make executable
   chkconfig --add glusterd
   chkconfig --level 35 glusterd on
   service glusterd start #start daemon for the first time
   # Set firewall:
   iptables --delete Chuck_Norris --jump REJECT --reject-with icmp-host-prohibited
   iptables --append Chuck_Norris --match state --state NEW --match tcp --protocol tcp --destination-port 111 --jump ACCEPT #port mapper runs on TCP 111
   iptables --append Chuck_Norris --match state --state NEW --match udp --protocol udp --destination-port 111 --jump ACCEPT #port mapper runs on UDP 111
   iptables --append Chuck_Norris --match state --state NEW --match tcp --protocol tcp --destination-port 24007:24009 --jump ACCEPT # ports 24007 and 24008 should be opened by default, 24009 = 24008 + (number of bricks in volume, in this case one brick per volume)
   iptables --append Chuck_Norris --jump REJECT --reject-with icmp-host-prohibited #deny everything else
   service iptables save
   service iptables restart
}

# Creates a new gluster volume.
# Gluster should be installed beforehand.
# $1 the name of the volume, i.e. data
# $2 the path of the actual folder that will be shared across nodes, i.e. /etc/data
function create_gluster_volume {
   local volume=${1-"root"}
   local path=${2-"/root/"}
   gluster volume create $volume transport tcp $(get_primary_ip)":"$path #create volume and add first brick
   gluster volume info #display volume info
   gluster volume log filename $volume /var/log/gluster/$volume/ #set logs
   gluster volume log locate $volume #display logs info
   gluster volume log rotate $volume #rotate logs
   gluster volume start $volume #start volume - yeah baby
}

# Expands the specified gluster volume.
# Gluster should be installed beforehand.
# Should be run on the first node of the volume.
# $1 hostname or ip address of the gluster expansion server
# $2 the name of the volume, i.e. data
# $3 the path of the actual folder that will be shared across nodes, i.e. /etc/data
function expand_gluster_volume {
   local host=$1
   local volume=$2
   local path=$3
   gluster peer probe $host #probe new host
   gluster volume add-brick $volume $host":"$path #add new brick to volume
   gluster volume info #display volume info
   gluster volume rebalance $volume start #rebalance the data among the bricks (process execution continues in the background)
}

# Mounts the specified volume to the supplied path.
# Gluster should be installed beforehand.
# $1 hostname or ip address of the GlusterFS primary server
# $2 the name of the volume
# $3 the path of the mount point for the local machine
function mount_gluster_volume {
   local host=$1
   local volume=$2
   local path=$3
   local home="/opt/gluster"
   mkdir $path #create the mount point
   if mount|grep $path; then umount $path; fi #make sure that mount point is not already in use
   echo -e "$host:/$volume $path glusterfs defaults,_netdev,log-level=WARNING,log-file=/var/log/gluster.log,transport=tcp,acl 0 0" >> /etc/fstab
   mount $path
}
