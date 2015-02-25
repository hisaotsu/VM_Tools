README.md
=========

This describes the followings about the backup script.

* Overview
* Prerequisites
* Installation
* How To Use
* What It Does
* Inside backup script
  * Backup state machine
  * Customization
  
## Overview

This backup script export VirtualBox VM images to a designated directory speci-
fied by NAS_MOUNTPOINT. It has the following capabilities during backup.

1. Selecting the VMs that require backup.
2. Changing the order of backup if the VM is running.
3. If the running VM is only VM that requires backup, it will retry. 
4. Set ARCHIVED state to backup instances.
5. Exclude VMs from back up that are in ARCHIVED state.
6. Reset ARCHIVED state to backup instances.

## Prerequisites

This script requires the followings.
  * The backup directory must exist either locally for remotely mounted.
  * The user running this script must have read/write access right.
  * The user must be able to run VBoxManage command.

## Installation

Download this script and give execute permission.

## How To Use

backupvm.sh [-archive|-pullout <VM name>]

## What It Does

__Default Behavior__

This program keeps the previous VM state in its state database.
If the VM has been used since the last backup, they will be schduled for backup.
However, if a VM has "ARCHIVED" state in state database, this VM will not be
scheduled for backup.

__-archive Option Specified__

This option sets the ARCHIVED state in the state database for the given VM.
When this option is specified, backup will not be started.  This only
updates the state database and move the backup image to ARCHIVE_DIR directory.

__-pullout Option Specified__

This option resets the ARCHIVED state in the state database for the given VM.
When this option is specified, backup will not be started.  This only
updates the state database and move the backup image to NAS_MOUNTPOINT 
directory.

### Backup instances

Backup instances refers to the collection of the followings.
  * Name of VM
  * Previous VM state from VirtualBox
  * VM state from VirtualBox
  * Path to the backups (exported copies of the VM)
  * Exported copy of VM
  * Exported copy of VM in the last backup
  * Backup state 

Since each item above may be stored in the different directores under
NAS_MOUNTPOINT directory, we collectively refers them as backup instances.
The information attached to each backup instances is stored in state
database. 

### Backup state machine

Since this script wants to reschedule the backkup order flexibly, it 
uses a simple state machine.  The below are state of backup instances.

    - NEW
    - BACKUP_NECESSARY
    - BACKUP_IN_PROGRESS
    - CLEAN
    - RUNNING
    - ARCHIVED

__NEW__

When script first finds the new VM, the backup instance is set to NEW.

__BACKUP_NECESSARY__

If the VM state is different from last VM state in VirtualBox or the previous
state is NEW, it will be set to BACKUP_NECESSARY.  These backup instances are
candidate for backup.
The VMs in RUNNING state will come into this state after VM stops.
 
__BACKUP_PROGRESS__

During backup, the state is set to BACKUP_IN_PROGRESS.

__CLEAN__

When backup is complete, it will be set to CLEAN state.

__RUNNING__

When the VM is still running during the status update, it wil be set to RUNNING.
The VMs in this state will be deferred for backup.  The next state is
BACKUP_NECESSARY.

__ARCHIVED__

VMs in this state will not be scheduled for backup.
The status will not change unless updated by the command.

### State database
### Customization
