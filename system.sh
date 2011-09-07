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

# Updates currently installed system packages.
function update {
   yum -y update
}

# Installs extra packages and repositories.
function install_extras {
   # Install EPEL repository:
   case $(cat /etc/redhat-release | sed -e "s|^.*\(CentOS\).*\([0-9]\+\.[0-9]\+\).*$|\1 \2|") in #in case distro name is ..
      'CentOS 6.0')
         rpm -Uvh http://download.fedora.redhat.com/pub/epel/6/x86_64/epel-release-6-5.noarch.rpm
         ;;
      *)
         echo "Distro not supported."
         return 0 #exit
         ;;
   esac
   # Install priorities to enforce the ordered protection of repositories:
   yum install -y yum-plugin-priorities
   # Configure priorities (lower priority numbers mean higher repository priority):
   sed -i \
-e "/^priority/d" \
-e "/\[base\]/a \
priority=1" \
-e "/\[updates\]/a \
priority=1" \
-e "/\[extras\]/a \
priority=1" \
/etc/yum.repos.d/CentOS-Base.repo
   sed -i \
-e "/^priority/d" \
-e "/\[epel\]/a \
priority=10" \
/etc/yum.repos.d/epel.repo
   yum check-update
   # Install extra packages:
   yum install -y htop system-config-securitylevel jwhois openssh-clients wget less vim gcc make automake autoconf bind-utils
}

# Promotes the specified user to sudoer.
# User will be able to run all commands (similar to root).
# $1 username {REQUIRED}
function set_superuser {
   local user=$1
   # Make sure user is specified:
   if [ -z $user ] ; then #user not specified
      echo "User name must be specified."
      return 0 #exit
   fi
   # Make sure user exists:
   if ! grep -iq "^$user" /etc/passwd ; then #user does not exist
      echo "User \"$user\" does not exist."
      return 0 #exit
   fi
   # Set as superuser:
   usermod --append --groups wheel $1 #append user to wheel group
   sed -i -e "s|^\(#\?\)\(\s\?\)\(%wheel\)\(\s\+\)\(ALL=(ALL)\)\(\s\+\)\(NOPASSWD:\sALL\)\(.*\)$|\3 \5 \7|" /etc/sudoers #allow wheel group to run all commands (similar to root)
}

# Sets system timezone to UTC/GMT.
function set_timezone {
   ln -sf /usr/share/zoneinfo/UTC /etc/localtime
}
