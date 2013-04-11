#!/bin/ksh
#==============================================================
#
# Virtual Machine Backup Script
# 
# Copyright © 2012 - 2013 by Hisao Tsujimura
#
# 2013/03/26 Version 3.0 - rewrite of the tool
# 2013/04/02 Version 3.0, fix 20130402a
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
## export DEBUG='true' # debug flag.  comment out when running
                    # actual backup.

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

	VM_STATE_FILE=$VM_STATE_DIR'/'$VM_name'.state'
	
	### debug code
	### echo '### DEBUG state file path='$VM_STATE_FILE

### If te file is there, check the VM status and compare
### with the previous state file.  If not, we need backup.

    if [ -f $VM_STATE_FILE ]
    then
        VBoxManage showvminfo $i > $TEMPFILE
        STAT=`diff $TEMPFILE $VM_STATE_DIR/$i.state`
        case $STAT in
        '')
            verbose '--- VM '$i' has no change.'
            export RC='false'
            ;;
        *)
            verbose '--- VM '$i' needs backup.'
            export RC='true'
            ;;
        esac
    else
        verbose '-- VM '$i' was never backed up.'
        export RC='true'
    fi

	### echo $RC
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
SKIP='false'

case $VM_STATE in 
'true')
	verbose ':::: VM is running.  Aborting export for VM='$VM_name
	SKIP='true'
	;;
esac
	
check_vm_state_update $VM_name

case $RC in
'false')
	verbose ':::: backup is not necessary.'
	SKIP='true'
	;;
*)
    verbose ':::: backup is necessary.'
    continue
esac

case $DEBUG in
'')
	continue
	;;
*)
	verbose '### DEBUG skipping backup'
	SKIP='true'
	;;
esac

##### now the VM is not runinng and backup IS necessary, so run it.

case $SKIP in
'false')
	#since VM is NOT running, do main backup.
	verbose ':::: moving old backup.'
	rm -rf $NAS_MOUNTPOINT/$VM_name.old 2> /dev/null
	mv $NAS_MOUNTPOINT/$VM_name $NAS_MOUNTPOINT/$VM_name.old 2> /dev/null
	
	# now do actual export
	
	verbose ':::: exporting: '$VM_name' ...'
	verbose `date`
	mkdir -p $NAS_MOUNTPOINT/$VM_name 2> /dev/null
	
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
'true')
	verbose 'skipping back up of VM='$VM_name
	;;
esac
}

#--------------------------------------------------------------
#Main Routine
#--------------------------------------------------------------

START_DATE=`date`

show_title
#### check if mount point is available
check_mount_point
case $RC in 
0)
	continue;;
16)
	exit;;
esac

#### check repository is available
make_state_repository

#### do backup to all VMs.  backup_this_vm() will judge if the backup is necessary.
echo '-- backing up VMs (if any)'
START_DATE=`date`

#### backup each VM
LIST_OF_VMS=`get_vm_list`
verbose 'List of VMs registered:'

### 2013.04.11 list VMs one VM per line instead of everything in the same line.
for i in `echo $LIST_OF_VMS`
do
    verbose '-- '$i
done

for i in $LIST_OF_VMS
do
	backup_this_vm $i $DEBUG
done

### echo '### DBUG end of code'

END_DATE=`date`
verbose '  start date='$START_DATE
verbose '  end   date='$END_DATE
verbose '--------------------------------------------------------------'
verbose ' COMPLETE'
verbose '--------------------------------------------------------------'

