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

backupvm.sh [-archive|-activate] <VM name> 

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

__-activate Option Specified__

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

Since this script wants to reschedule the back up order flexibly, it 
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

When the VM is still running during the status update, it will be set to RUNNING.
The VMs in this state will be deferred for backup.  The next state is
BACKUP_NECESSARY.

__ARCHIVED__

VMs in this state will not be scheduled for backup.
The status will not change unless updated by the command.

### State database

1. Location

State database will reside in $NAS_MOUNTPOINT or backup directory.
The directory for state database is vmstate.
Sample location of state database is such as below.

  /Volumes/vm/vmstate

2. Compatibility

The older version of script used state files to preserve the previous state of 
the virtual machines.  This version of script is not compatible with the
state files.  Therefore, the previous state stored by the older version of the
script has no effect to the behavior of this script.  All VMs will be treated
as NEW in state database.

3. State Database Struture

The state database consists of the following files.
    - vmtool-db-version
    - vmtool-statedb
    - vmtool-dblock

* vmtool-db-version
    This is the version of state database so that the future migration tool
    can check the version in future.  It contains the following fileds.
        TOOL_VERSION: <the version of the tool>
        DB_VERSION: <database version>
    The database version is currently 1.0.
    There is no migration tool available as of today, therefore the tool 
    version is set to 0.0. 

* vmtool-statedb
    This file cosists of the column separated values such as:
        vm1:RUNNING

    The current format is:
        <vmname>:<status>

* vmtool-dblock
    This file is used to lock the database.  When the script is run from only one 
    node, locking of the database is not necesary.  However, if you are backing 
    up the VMs from multiple nodes and sharing state database, a simultaneous 
    update can accidentally destroy the database.

### Workers

In order to make the backup run simultaneously, I introduced "worker" structure.
Workers are implemented as functions in the script, and called serially as of 
today, and implemented as a single script.

To Do:  separate workers into different scripts and let them run simultaneously,
using the state database as the means of synchronization.

#### Backup Workers

Backup workers are in charge of the followings.

(1) Starting VBoxManage commands in the back ground.
(2) Monitoring the VBoxManage command running.
(3) Call database workers to update state database.

Caveat:  I need to check what happens when VBoxManage startvm is run while we 
are exporting the VM.

#### vmfind Worker 

vmfind worker is in charget of finding new VMs that are not listed in the state 
database and call database workers to update the database.

#### State Change Notifier

State Change notifier checks the state of database and call database workers 
to update state database.

#### Database Workers

Database workers are in charge of maintaining state database.
It has the following functions.

- Obtaining an exclusive lock
- Releasing an exclusive lock
- Adding record to database
- Updating record to database
- Deleting record from database



