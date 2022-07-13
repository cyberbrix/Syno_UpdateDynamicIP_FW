#!/bin/bash

ddnsname="<Your DynamicIP FQDN>"

#check if firewall update installed
synofwpath=$(which synofirewall)
if [ -z "$synofwpath" ]
then
  echo "synofirewall command not found"
  exit 1
fi


# Detect local path
LocalPath=$(dirname "$0")
LocalPath=$(cd "$LocalPath" && pwd)

if [[ -z "$LocalPath" ]]
then
  echo "Bad path for $LocalPath"
  exit 1
fi

# Grab current IP for DNS entry
registeredip=$(nslookup $ddnsname  | awk -F': ' 'NR==6 { print $2 } ')
[[ $registeredip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
if [[ $? != 0 ]]
then
  echo "Resolved $registeredip for $ddnsname"
  exit 1
fi

# Identify file for old dynamic IP
oldipfile="$LocalPath/olddynip.txt"

# Test if file exists
if [ ! -f "$oldipfile" ]
then
  echo "$oldipfile does not exist."
  echo $registeredip > "$oldipfile"
  exit 0
fi

oldip=$(cat "$oldipfile")
[[ $oldip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
if [[ $? != 0 ]]
then
  echo "$HOSTNAME found bad IP: $oldip in $oldipfile"
  exit 1
fi

# Check if old IP and new IP are the same. Exit if so
if [ "$oldip" == "$registeredip" ]
then
  echo "CurrentIP: $oldip is same as $ddnsname: $registeredip"
  exit 0
fi

# Backup current firewall rules - forces an overwrite of existing files in $LocalPath
yes | cp -rf /usr/syno/etc/firewall.d/*.json $LocalPath/

# Replace firewalld json rules with new IP
sed -s -i "s/$oldip/$registeredip/g" /usr/syno/etc/firewall.d/*.json

# Reload firewall configuration
eval $synofwpath --reload

if [ $? -eq 0 ]
then
  echo $registeredip > "$oldipfile"
else
  echo "$HOSTNAME firewall did not update $oldip to $registeredip"
  exit 1
fi

exit 0
