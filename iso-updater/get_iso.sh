#!/bin/bash
# Copyright 2015 Mellanox Technologies, Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

get_iso_from_storage()
{
    jenkinsSlaveIP=$1
    jenkinsSlavePassword=$2
    fuel_version_name=$3
    fuel_iso_path=$4
    new_folder_name=$5

/usr/bin/expect << EOF
set timeout 3000
spawn scp -rp $jenkinsSlaveIP:fuel_6.1/iso/$fuel_version_name $fuel_iso_path/$new_folder_name
set timeout 3000
expect "yes/no" {
send "yes\r"
expect "*?assword" { send "$jenkinsSlavePassword\r" }
} "*?assword" { send "$jenkinsSlavePassword\r" }
expect "*#*"
EOF

}

fuel_iso_path=/root/fueliso
[ -d $fuel_iso_path ] || mkdir $fuel_iso_path

jenkinsSlaveIP=$1
jenkinsSlavePassword=$2
fuel_url=$3

# first we need to decide weather to get the iso from the storage or form the internet
# if the fuel url had http in it or equal to 0, then from the net,
# else:
#      get it from the storage
#      mlnx_plugin_enable should be true or false based on later requirements

substr=http

# flag 0 means no http in it
# flag 1 means there's http in it, so get it from the net
[[ $fuel_url == *"$substr"* ]] && flag=1 || flag=0


# check if to get the fuel version from the storage
size_url=${#fuel_url}
if [[ ("$flag" -eq 0) && ("$size_url" -gt "1") ]]; then

   # get iso from storage to pxe machine
   fuel_version_name=$fuel_url
   new_folder_name=$(sed "s/.iso//g" <<< $fuel_version_name)
   if [ -d ~/fueliso/$new_folder_name ]; then
      echo "you have this iso already there, just make sure to mount it"
   else
      mkdir -p $fuel_iso_path/$new_folder_name
      apt-get -y install expect
      get_iso_from_storage $jenkinsSlaveIP $jenkinsSlavePassword $fuel_version_name $fuel_iso_path $new_folder_name
   fi

   # make the path ready for the new mount
   pathToIso=$fuel_iso_path/$new_folder_name/$fuel_version_name

   # remove old mount
   rm -rf /var/lib/tftpboot/fuel

else

    # we wanna download the ISO:
    # Check if we have w3m rpm
    apt-get -y install -y w3m

    #in centos yum install –y aria2
    apt-get -y install aria2

    # Check if there's a passed parameter, then use it to download, else if it was 0 get the latest iso
    #------Check user supplied url
    if [ "$fuel_url" -eq 0 ]; then
       last_rel=$(w3m -dump -cols 400 https://www.fuel-infra.org/release/status#tab_4 | grep -v community-5 | grep "ok    ok      ok    ok" | head -1 | awk -F' ' '{ print $5 }')
       rel=$last_rel
    else

        # if no parameter found, download the latest version
        rel=$(echo $fuel_url | cut -d'/' -f5)
        rel=$(echo $rel | cut -d'?' -f1)
        rel=$(sed "s/.iso.torrent//g" <<< $rel)
    fi
    fuel_iso_path="$fuel_iso_path/$rel"
    pathToIso="$fuel_iso_path/$rel.iso"
    if [ -d $fuel_iso_path && -e $pathToIso ]; then
       echo "You got the latest ISO, no need to download any.."

       # just make sure to mount the new one
       test -d /var/lib/tftpboot/fuel || mkdir -p /var/lib/tftpboot/fuel
       test -d /var/lib/tftpboot/fuel || mkdir -p /mnt/fueliso

       # extract the iso file
       mount -o loop $pathToIso /mnt/fueliso

       # copy files extracted files
       rsync -a /mnt/fueliso/ /var/lib/tftpboot/fuel/

       # unmount the iso and remove the mount directory
       umount /mnt/fueliso && rmdir /mnt/fueliso
       exit 0
    else
        mkdir $fuel_iso_path
        rm -rf /var/lib/tftpboot/fuel
    fi
    if [ ! -f "$fuel_iso_path/$rel.iso" ]; then
       touch "$fuel_iso_path/$rel.iso.progress"
       aria2c -x10 http://seed.fuel-infra.org/fuelweb-iso/$rel.iso -d $fuel_iso_path -l $fuel_iso_path/$rel.iso.progress
       echo "http://seed.fuel-infra.org/fuelweb-iso/$rel.iso -b -o $fuel_iso_path$rel.iso.progress -P $fuel_iso_path"
    fi

    # make sure that previous finished successfully, if not, delete the directory that have been created for it
    grep -i "error" $fuel_iso_path/$rel.iso.progress
    res=$(echo $?)
    if [ "$res" -eq 0 ]; then

         # this means we had an error in it, delete folder created, then exit with error
         echo "error has been detected while downloading this build.. check the above progress file."
         rm -rf $fuel_iso_path
         exit 1
    fi
    pathToIso="$fuel_iso_path/$rel.iso"
fi

set -e

# create the follwoing 2 folders
mkdir -p /var/lib/tftpboot/fuel
mkdir -p /mnt/fueliso

# extract the iso file
mount -o loop $pathToIso /mnt/fueliso

# copy files extracted files
rsync -a /mnt/fueliso/* /var/lib/tftpboot/fuel/

# unmount the iso and remove the mount directory
umount /mnt/fueliso && rmdir /mnt/fueliso

exit 0