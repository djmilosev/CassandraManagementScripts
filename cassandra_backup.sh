#!/bin/bash

###
### Cassandra database backup shell script
### Back up keyspace schema and snapshots
### Author: Djordje Miloshevic
###

### VARIABLES

host={{ ansible_default_ipv4.address }}
backup_directory=/backup
data_directory=/var/lib/cassandra/data
nodetool=/usr/bin/nodetool
today_date=$(date +%F)

backup_snapshot_directory="$backup_directory/SNAPSHOTS"
backup_schema_directory="$backup_directory/SCHEMA"
snapshot_directory=$(find $data_directory -type d -name snapshots)
snapshot_name=snp-$(date +%F-%H%M-%S)
#schema_date=$(date +%F-%H%M-%S)

### CREATE / CHECK BACKUP DIRECTORY

if [ -d  "$backup_schema_directory" ]; then
 echo "$backup_schema_directory already exist, proceeding!"
else
 echo "Creating $backup_schema_directory directory!"
 mkdir -p "$backup_schema_directory"
fi

if [ -d  "$backup_snapshot_directory" ]; then
 echo "$backup_snapshot_directory already exist, proceeding!"
else
 echo "Creating $backup_snapshot_directory directory!"
 mkdir -p "$backup_snapshot_directory"
fi

### ENSURE THAT PREVIOUS BACKUPS ARE DELETED

# schemas

if [ $(find $backup_schema_directory -maxdepth 0 -type d -empty 2>/dev/null) ]; then
 echo "$backup_schema_directory is empty, proceeding!"
else
 echo "$backup_schema_directory directory not empty, deleting old backups!"
 rm -rf "$backup_schema_directory"/*
fi

# snapshots

if [ $(find $backup_snapshot_directory -maxdepth 0 -type d -empty 2>/dev/null) ]; then
 echo "$backup_snapshot_directory directory is empty, proceeding!"
else
 echo "$backup_snapshot_directory directory not empty, deleting old backups!"
 rm -rf "$backup_snapshot_directory"/*
fi


############ BACKUP STAGE 1: SCHEMA BACKUP ###############

cqlsh $host -e "DESC KEYSPACES" | perl -pe 's/\e([^\[\]]|\[.*?[a-zA-Z]|\].*?\a)//g' | sed '/^$/d' > keyspace_schema_list.cql

### CREATE DIRECTORY INSIDE BACKUP SCHEMA DIRECTORY, AS PER KEYSPACE NAME

for i in $(cat keyspace_schema_list.cql); do

 if [ -d $i ]; then
  echo "$i directory exist"
 else
  mkdir -p $backup_schema_directory/$i
 fi

done

### RUN ACTUAL SCHEMA BACKUP

for keyspace in $(cat keyspace_schema_list.cql); do

 cqlsh $host -e "DESC KEYSPACE  $keyspace" > "$backup_schema_directory/$keyspace/$keyspace"_schema.cql 

done

############ BACKUP STAGE 1: SNAPSHOTS ###############

echo "Creating SNAPSHOTS for all keyspaces..."
$nodetool snapshot -t $snapshot_name

### GET SNAPSHOT DIRECTORY PATH
snapshot_directory_list=`find $data_directory -type d -name snapshots|awk '{gsub("'$data_directory'", "");print}' > snapshot_dir_list`

### CREATE DIRECTORY INSIDE BACKUP SNAPSHOTS DIRECTORY, AS PER KEYSPACE NAME

for i in `cat snapshot_dir_list`; do

 if [ -d $backup_snapshot_directory/$i ]; then
  echo "$i directory exist, proceeding"
 else
  mkdir -p $backup_snapshot_directory/$i
  echo "$i Directory is created"
 fi

done


### COPY DEFAULT SNAPSHOT DIR TO BACKUP DIR

find $data_directory -type d -name $snapshot_name > snapshot_dir_list

for snapshot in `cat snapshot_dir_list`; do

## Triming data_directory
snapshot_path_trim=`echo $snapshot|awk '{gsub("'$data_directory'", "");print}'`
cp -prvf "$snapshot" "$backup_snapshot_directory$snapshot_path_trim";

done