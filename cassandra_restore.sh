#!/bin/bash

###
### cassandra database restore script
### script will require the keyspace name as input
### after valid keyspace name is entered, script will restore schema and data for the specified keyspace
### Author: Djordje Miloshevic
###

# variables
host=10.10.20.231
cqlsh=/usr/bin/cqlsh
today_date=$(date +%F)
nodetool=/usr/bin/nodetool

backup_directory=/backup
data_directory=/var/lib/cassandra/data
backup_snapshot_directory="$backup_directory/SNAPSHOTS"
backup_schema_directory="$backup_directory/SCHEMA"
snapshot_directory=$(find $data_directory -type d -name snapshots)

### first part: restore schemas from backup

# check if keyspace schema exist, if not break
echo "Please enter the name of the keyspace to be restored:"
read keyspace


if [ -f "$backup_schema_directory"/"$keyspace"/"$keyspace"_schema.cql ]; then
 echo
 echo "Valid schema file found, performing schema backup for $keyspace keyspace!"
 echo
else
 echo
 echo "Aborting! Please enter the correct keyspace name!"
 echo
 exit 1
fi

# Restore the schema for specified keyspace
schema="$backup_schema_directory"/"$keyspace"/"$keyspace"_schema.cql
#echo $schema
cqlsh $host -e "source '$schema'"

### second part: restore snapshots from backup

# check the tables for specified keyspace
nodetool cfstats $keyspace | grep "Table: " | sed -e 's+^.*: ++' > "$keyspace"_tables.cql

for table in $(cat "$keyspace"_tables.cql); do

 ## determine table id's
 source_table_id=`find $backup_snapshot_directory -name "$table*" | cut -d '/' -f 5 | perl -pne 's/(.+)\-(\w+)$/$2/'`
 dest_table_id=$(find $data_directory -name "$table*" | cut -d '/' -f 7)

 ## determine snapshot names
 snapshot_name=`find $backup_snapshot_directory/$keyspace/"$table"-"$source_table_id"/snapshots/ -name "snp*" | cut -d '/' -f 7  | sed 's|.*,\(..\)/\(..\)/\(....\),$|\3-\2-\1|'`

 ## determine source and destination path
 source=$backup_snapshot_directory/$keyspace/"$table"-"$source_table_id"/snapshots/$snapshot_name
 dest=$data_directory/$keyspace/$dest_table_id/

 echo
 echo "Restoring table $table for keyspace $keyspace"
 echo

 ## restore the snapshot files to $data_directory
 rsync -aP $source/* $dest

 ## refresh keyspace
 $nodetool refresh $keyspace $table

done

