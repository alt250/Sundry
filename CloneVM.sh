#!/bin/sh

# CloneVM.sh for VMWare ESXi 4.1 & ESXi 5.x
# By Rich Manton
#
# 25th Jan 2014
#

# Version 1.0
# Initial Release

version=1.0
numargs=$#
showhelp=0

if [ $numargs -lt 2 ] || [ "$1" = "-h" ]; then
  showhelp=1
fi

if [[ $showhelp -eq 1 ]]; then
    echo
    echo "Syntax: CloneVM.sh [full.path.to.source.vm] [full.path.to.target.vm] [-r]"
    echo "    eg: CloneVM.sh /vmfs/volumes/store1/srcvm /vmfs/volumes/store2/tgtvm -r"
    echo
    echo "        -r: Optional Parameter. Registers the new cloned VM in ESXi host inventory"
    echo "        -h: Displays help/syntax (this)"
    echo
    exit 0
fi

OLDVMSTORE="${1%/*}"
OLDVM="${1##*/}"
OLDVMID=$(vim-cmd vmsvc/getallvms | sed -e '1d' -e 's/ \[.*$//' | awk '$1 ~ /^[0-9]+$/ {print $1":"substr($0,8,80)}' | grep "$OLDVM" | awk -F':' '{print $1}')
if [ ! -z $OLDVMID ]; then
  OLDVMPS=$(vim-cmd vmsvc/power.getstate $OLDVMID | tail -1)
fi
NEWVMSTORE=${2%/*}
NEWVM="${2##*/}"
ADDVMTOINV=0

echo
echo "CloneVM.sh for VMWare ESXi 4.1 & ESXi 5.x"
echo "-----------------------------------------"
echo
echo "OLD VM DATASTORE : $OLDVMSTORE"
echo "OLD VM           : $OLDVM"
echo
echo "NEW VM DATASTORE : $NEWVMSTORE"
echo "NEW VM           : $NEWVM"
echo

if [ ! -z "$3" ]; then
  if [ "$3" == "-r" ]; then
    echo "-r specified, cloned VM will be added to ESXi host inventory"
    echo
    ADDVMTOINV=1
  fi
else
  echo "-r not specified, cloned VM will not be added to ESXi host inventory"
  echo
fi

if [ "$OLDVMPS" = "Powered on" ]; then
  echo "Virtual machine $OLDVM is powered on.  Please power off before performing clone operation"
  echo
  exit 1
fi

if [ ! -d "$OLDVMSTORE/$OLDVM" ]; then # source does not exist, do not proceed
  echo "Source VM Directory does not exist, exiting script"
  exit 1
fi

if [ -d "$NEWVMSTORE/$NEWVM" ]; then # target already exists, do not proceed
  echo "Target VM Directory already exists, exiting script"
  exit 1
else
  mkdir "$NEWVMSTORE/$NEWVM"
fi

# Perform the VMDK Clone
VM_VMDK_DESCRS=$(ls "$OLDVMSTORE/$OLDVM" | grep ".vmdk" | grep -v "\-flat.vmdk")
for VMDK in "${VM_VMDK_DESCRS}"
do
  echo "Cloning VMDK : $VMDK"
  NEWVMDK=$(echo ${VMDK##*/} | sed "s/$OLDVM/$NEWVM/")
  vmkfstools -i "$OLDVMSTORE/$OLDVM/$VMDK" "$NEWVMSTORE/$NEWVM/$NEWVMDK" -d thin
  echo
done

# copy remaining vm files from old vm path to new path, renaming files with new vm name where required
echo "Copying Supporting Files:"
OLD_IFS="$IFS"
IFS=$'\n'
for f in $(find "$OLDVMSTORE/$OLDVM/" -type f)
do
  if [ ! ${f##*.} = vmdk ]; then
    NEWFILE=$(echo ${f##*/} | sed "s/$OLDVM/$NEWVM/")
    echo "Copying $f to $NEWVMSTORE/$NEWVM/$NEWFILE"
    cp $f "$NEWVMSTORE/$NEWVM/$NEWFILE"
  fi
done
IFS="$OLD_IFS"
echo

# modify new vm file
echo "Updating $NEWVMSTORE/$NEWVM/$NEWVM.vmx"
echo
sed -i "s/$OLDVM/$NEWVM/g" "$NEWVMSTORE/$NEWVM/$NEWVM.vmx"

# Add new VM to ESXi inventory
if [ $ADDVMTOINV -eq 1 ]; then
  echo "Registering $NEWVM into ESXi Host Inventory"
  echo
  vim-cmd solo/registervm "$NEWVMSTORE/$NEWVM/$NEWVM.vmx" > /dev/null
fi
