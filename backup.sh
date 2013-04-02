#!/bin/ksh
#==============================================================
#
# Virtual Machine Backup Script
# 
# Copyright © 2012 - 2013 by Hisao Tsujimura
#
# 2013/03/26 Version 3.0 - rewrite of the tool
#==============================================================
#--------------------------------------------------------------
# Variables
#--------------------------------------------------------------
export VERSION=3.0
export NAS_MOUNTPOINT=/Volumes/vm
##export NAS_MOUNTPOINT=/Volumes/export/vm
export VM_STATE_DIR=$NAS_MOUNTPOINT/vmstates
export TEMPFILE=$VM_STATE_DIR/tempfile.temp
export LOG_FILE='./backup_sh.log'

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

#--------------------------------------------------------------
# Functions - state repository functions
#--------------------------------------------------------------
#
# function : make_state_repository
# arguments: none
# usage    : make_state_repository
# description:
#  This function creates a repository based on the following
#  variable preset make_state_repository().
#  $VM_STATE_DIR

make_state_repository()
{
	mkdir -p $VM_STATE_DIR 2> /dev/null
}

#
# function : store_vm_state
# arguments: <VM name>
# usage    : store_vm_state <VM name>
# description:
#  This stores the Virtual Machines status and store in the 
#  repository or $VM_STATE_DIR.
#
store_vm_state()
{
	VM_name=$1	#preserve the parameter passed.
	
	verbose '::: saving VM state…'
	VBoxManage showvminfo $VM_name > $VM_STATE_DIR/$VM_name.state
}

# function : check_vm_state_update
# arguments: <VM name>
# usage    : check_vm_state_update <VM name>
# description:
#   This function compares the previous state of the VM
#   stored in the repository with the current state of VM.
#   If they are different, it returns "true," and if not, "false."
check_vm_state_update()
{
	VM_name=$1	# preserve the parameter.

	### CHECK when the status does not exist.

	if [ !-f $VM_STATE_DIR/$VM_name.state ]
	then
		RC=true
	fi

	### CHECK when the status exist.
	if [ -f $VM_STATE_DIR/$VM_name.state ]
	then
		VBoxManage showvminfo $i > $TEMPFILE 
		STAT=`diff $TEMPFILE $VM_STATE_DIR/$i.state`

		case $STAT in
		'')
			verbose '--- VM '$i' has no change.'
			RC='false'
			;;
		*)
			verbose '--- VM '$i' needs backup.'
			RC='true'
			;;
		esac
	fi

	echo $RC
}


#--------------------------------------------------------------
# Functions - checking environment
#--------------------------------------------------------------
# function : check_mount_point
# arguments: none
# usage    : check_mount_point
# description:
#  This function checks if $NAS_MOUNTPOINT exist.
#  If it does, it returns true.  If not, it returns false.
# return values:  0 = success, 16=failed
#
# 2013.04.02 - now checking if actual moiunt point name is in $9 of df command 
# output.  This prevents code from giving a green light when the mount point
# is something like /Volumes/vm-1.

check_mount_point()
{

RC=0	# set RC=0.

STAT=`df -k | grep $NAS_MOUNTPOINT | awk '{print $9}'`

case $STAT in 
'')
	export RC=16
	verbose ' - backup directory '$NAS_MOUNTPOINT ' is not mounted.'
	verbose ' - exiting.'
	;;
$NAS_MOUNTPOINT)
	export RC=0
	;;
*)
	export RC=16
	verbose ' - backup directory '$NAS_MOUNTPOINT ' is not mounted.'
	verbose ' - exiting.'
	;;
esac

}

#--------------------------------------------------------------
# Function - backup
#--------------------------------------------------------------
# function : backup_this_vm
# arguments: <VM name>
# usage    : backup_this_vm
# description:
#   This function backup 1 VM.
backup_this_vm()
{
	VM_name=$1	# preserve parameter
	DEBUG=$2	# debug flag to skip actual export.

	verbose '- backup: VM='$VM_name
	
	## If the VM is running, skip it.

	VM_STATE=`vm_is_running $VM_name`

	case $VM_STATE in
	'false')
		#since VM is NOT running, do main backup.
		verbose ':::: moving old backup.'
		rm -rf $NAS_MOUNTPOINT/$VM_name.old 2> /dev/null
		mv $NAS_MOUNTPOINT/$VM_name $NAS_MOUNTPOINT/$VM_name.old 2> /dev/null

		# now do actual export
		
		verbose ':::: exporting: '$VM_name' ...'
		verbose `date`
		mkdir -p $NAS_MOUNTPOINT/$VM_name 2> /dev/null
		
		case $DEBUG in 
		'true')
				continue
				;;
		*)
			VBoxManage export $VM_name --output $NAS_MOUNTPOINT/$VM_name/$VM_name.ovf --ovf20
			RC=$?
			if [ $RC != 0 ]
			then
				verbose '!!! export did not end normally. rc='$RC
			fi
			if [ $RC = 0 ]
			then
				# now store new VM state
				store_vm_state $VM_name
			fi
			;;
		esac
		;;
	'true')
		verbose ':::: '$VM_name 'is running - skipping.'
		;;
	esac
}


#--------------------------------------------------------------
#Main Routine
#--------------------------------------------------------------
DEBUG='true'	# debug flag
START_DATE=`date`

show_title
make_state_repository
check_mount_point
case $RC in 
0)
	continue;;
16)
	exit;;
esac

echo '### DBUG end of code'

echo '-- backing up VMs (if any)'
START_DATE=`date`

for i in `get_vm_list`
do
	echo $i
	backup_this_vm $i $DEBUG
done

END_DATE=`date`
verbose '  start date='$START_DATE
verbose '  end   date='$END_DATE
verbose '--------------------------------------------------------------'
verbose ' COMPLETE'
verbose '--------------------------------------------------------------'

