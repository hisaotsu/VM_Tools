#!/bin/ksh 
#==================================================================
#
# VirtualBox Management Scripts
#
# script name   : backupvm.sh
#
# what this does:
#  This script takes the list of Virtual Machines (VMs) from 
#  VirtualBox by using VBoxManage command line interface
# 
#* Revision Hisotry
# 2015/02/21 Version 4.0 alpha1 - redesgin of the script 
#
#==================================================================
#------------------------------------------------------------------
# Variables
#------------------------------------------------------------------
export VERSION='4.0_alpha1'
export VM_STATE_DIR=$NAS_MOUNTPOINT/vmstates
export TEMPFILE=$VM_STATE_DIR/tempfile.temp
export LOG_FILE='./backup_sh.log'
export DEBUG='true' # debug flag.  comment out when running
                    # actual backup
                    
#--------------------------------------------------------------
# Functions - Logging function
#--------------------------------------------------------------

# keep log of the script
verbose()
{
	echo $* 
	echo `date +%Y/%m/%d_%H:%M:%S`': '$* >> $LOG_FILE
}

#--------------------------------------------------------------
# Functions - cosmetic messages
#--------------------------------------------------------------

# title screen
show_title()
{
	clear
	verbose '--------------------------------------------------------------'
	verbose ' VM backup script / version='$VERSION
	verbose '--------------------------------------------------------------'
}

#--------------------------------------------------------------
# Functions - VirtualBox related functions
#--------------------------------------------------------------
#
# function : get_vm_list
# arguments: none
# usage    : get_vm_list
# description:
#  This function returns the name of registered virtual machine 
#  names delimited by white spaces.

get_vm_list()
{
VBoxManage list vms | sed 's/{.*}//' | \
		      sed 's/\"//' | \
		      sed 's/\"//' 
}

#
# function : vm_is_running
# arguments: <VM name>
# usage    : vm_is_running <VM name>
# description:
#  This function returns the followings.
#	If the VM specified by VM is:
#		running     - "true"
#		not running - "false"
#
vm_is_running()
{
	state=`VBoxManage list runningvms | grep $1`
	case $state in
	'')
		echo 'false';;
	*)
		echo 'true';;
	esac
}


