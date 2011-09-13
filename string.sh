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

# Escapes the specified string, so it may be used in sed directives, etc.
# $1 the string, i.e. '/mnt/data'. {REQUIRED}
function string.escape {
   local string="$1"
   # Make sure string is specified:
   if [ -z $string ] ; then #string not specified
      echo "A string must be specified."
      return 1 #exit
   fi
   # Escape string:
   echo $path | sed 's|/|\\/|g' #escape path '/' character to use it in sed
   return 0 #done
}
