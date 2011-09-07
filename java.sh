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

JDK6_URI="http://download.oracle.com/otn-pub/java/jdk/6u27-b07/jdk-6u27-linux-x64-rpm.bin"

# Installs the latest version of Oracle JDK 6.
function install_jdk6 {
   # Install prerequisites:
   yum -y install jpackage-utils
   # Donwload, compile & install files:
   cd ~
   wget --output-document=jdk-linux-x64-rpm.bin $JDK6_URI #obtain rpm files
   unzip jdk-linux-x64-rpm.bin -d jdk-linux-x64-rpm #unpack archive
   cd jdk-linux-x64-rpm
   yum -y --nogpgcheck localinstall jdk*.rpm #install java from local rpm file
   java -version #echo java version
   # Collect garbage:
   cd ~
   rm -rf jdk*
}
