#!/bin/ksh
#==============================================================
#
# Virtual Machine Backup Script
# 
# 2012.07.21 Version 2.0 by Hisao Tsujimura
# 2012.07.21 Version 2.1 by Hisao Tsujimura
# 	Added to record return code from VBoxManage export
# 2012.07.24 Version 2.2 by Hisao Tsujimura
#	bug fix -- remove .old directory.
# 2012.07.27 Version 2.3 by Hisao Tsujimura
#	added backup one feature, which will ask 1 VM to backup
#	  <syntax> ./backup.sh one
# 2012.09.25 Version 2.4 by Hisao Tsujimura
#	add start date and end date display
# 2013.03.11 Version 2.5 by Hisao Tsujimura
# 	add -ovf20 parameter to export in ovf20.
#==============================================================
#--------------------------------------------------------------
# Variables
#--------------------------------------------------------------
export VERSION=2.5
export NAS_MOUNTPOINT=/Volumes/vm
##export NAS_MOUNTPOINT=/Volumes/export/vm
export VM_STATE_DIR=$NAS_MOUNTPOINT/vmstates
export TEMPFILE=$VM_STATE_DIR/tempfile.temp
export LOG_FILE='./log_backup.txt'
#--------------------------------------------------------------
# functions
#--------------------------------------------------------------
# keep log of the script
verbose()
{
	echo $* 
	echo `date +%Y/%m/%d_%H:%M:%S`': '$* >> $LOG_FILE
}

# title screen
show_title()
{
	clear
	verbose '--------------------------------------------------------------'
	verbose ' VM backup script / version='$VERSION
	verbose '--------------------------------------------------------------'
}

# get list of all registerd virtual machines
get_vm_list()
{
##VBoxManage list vms | awk '{print $1}' | \
## 		      awk '{printf("%s "),substr($0,2,length($0)-2);}' | \
##		      sort -n
VBoxManage list vms | sed 's/{.*}//' | \
		      sed 's/\"//' | \
		      sed 's/\"//' 
}

# show list of all registered virtual machines
display_vm_list()
{
	verbose '  - currently registered virtual machines'
	VBoxManage list vms | awk '{print $1}'
}

# function to check if the vm is running
vm_running()
{
	state=`VBoxManage list runningvms | grep $1`
	case $state in
	'')
		echo 'false';;
	*)
		echo 'true';;
	esac
}

backup_vm()
{
	VM_name=$1
	
	STAT=`vm_running $VM_name`
	if [ $STAT = 'true' ]
	then
		verbose '::: Virual Machine '$VM_name' is running.'
		verbose '::: exiting...'
		exit
	fi

	### make the backup of the old backup
	#verbose '- moving current backup to old if any...'
	# // 2012.07.24 bug fix
	rm -rf $NAS_MOUNTPOINT/$VM_name.old 2> /dev/null
	mv $NAS_MOUNTPOINT/$VM_name $NAS_MOUNTPOINT/$VM_name.old 2> /dev/null
	verbose ':::: exporting: '$VM_name' ...'
	verbose `date`
	mkdir -p $NAS_MOUNTPOINT/$VM_name 2> /dev/null
	VBoxManage export $VM_name --output $NAS_MOUNTPOINT/$VM_name/$VM_name.ovf --ovf20
	RC=$?
	if [ $RC != 0 ]
	then
		verbose '!!! export did not end normally. rc='$RC
	fi

	VBoxManage showvminfo $VM_name > $VM_STATE_DIR/$VM_name.state
}
#--------------------------------------------------------------
# test code
#--------------------------------------------------------------
export FLAG=$1

show_title
echo '### DEBUG flag='$FLAG


# check if backup directory is ready.  if not, end the program...
if [ ! -d $NAS_MOUNTPOINT  ]
then
	verbose ' - backup directory '$NAS_MOUNTPOINT ' is not mounted.'
	verbose ' - exisiting.'
	exit 16
fi

### get vm list and for each VM, compare with the last status of
### vm with the current output.  If the status is any way different,
### put them into the backup list
VMS=`get_vm_list`
mkdir $VM_STATE_DIR 2> /dev/null

verbose '---- checking if each VM needs backup'
for i in $VMS
do
	if [ ! -f $VM_STATE_DIR/$i.state ]
	then 
		BACKUP_LIST=$BACKUP_LIST' '$i
	fi

	if [ -f $VM_STATE_DIR/$i.state ]
	then
		VBoxManage showvminfo $i > $TEMPFILE 
		STAT=`diff $TEMPFILE $VM_STATE_DIR/$i.state`

		case $STAT in
		'')
			verbose '--- VM '$i' has no change.'
			;;
		*)
			verbose '--- VM '$i' needs backup.'
			BACKUP_LIST=$BACKUP_LIST' '$i
			;;
		esac
	fi
done

###
### backup one -- override BACKUP_LIST if "one" is specified
###
case $FLAG in
'one')
	verbose '=== You specified to back up only one VM.'
	verbose '=== Which of the following VMs would you like to backup?'
	echo $VMS
	read THIS_VM
	case $THIS_VM in
	'')
		continue;;
	*)
		STAT=`echo $VMS | grep $THIS_VM`
		case $STAT in 
		'')
			continue;;
		*)
			BACKUP_LIST=$THIS_VM;;
		esac
		;;
	esac
	;;
esac

###
### backup VMs
###

echo '-- backing up VMs (if any)'
START_DATE=`date`
for i in $BACKUP_LIST 
do
	backup_vm $i
done
END_DATE=`date`
verbose '  start date='$START_DATE
verbose '  end   date='$END_DATE
verbose '--------------------------------------------------------------'
verbose ' COMPLETE'
verbose '--------------------------------------------------------------'

