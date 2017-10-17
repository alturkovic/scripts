#!/usr/bin/env bash

#########################################################
#                                                       #
# Redis RDB database dump encryption and backup utility #
#                                                       #
# Configuration variables                               #
#                                                       #
# Modify accordingly                                    #
#                                                       #
######################################################### 

# Source file to backup
# default: '/var/lib/redis/dump.rdb'

# _source_file=

# Backup directory
# default: '/var/lib/redis/backup/'

# _backup_dir=

# Compress before encryption
# default: 't'

# _compress=

# OpenSSL pass argument
# See openssl(1) -pass argument man page for details

_openssl_pass=

#########################################################
#                                                       #
# DON'T MODIFY AFTER THIS                               #
#                                                       #
#########################################################

# apply defaults if not present

if [ -z "$_source_file" ]; then
  _source_file='/var/lib/redis/dump.rdb'
fi

if [ -z "$_backup_dir" ]; then
  _backup_dir='/var/lib/redis/backup/'
fi

if [ -z "$_compress" ]; then 
  _compress='t'
fi 

if [ -z "$_compression_tool" ]; then
  _compression_tool='gzip'
fi

if [ -z "$_compression_args" ]; then
  _compression_args='--best -c'
fi

if [ -z "$_compressed_suffix" ]; then
  _compressed_suffix='.gz'
fi

if [ -z "$_remove_older" ]; then
  _remove_older='t'
fi 

if [ -z "$_max_age" ]; then 
  _max_age=7
fi

# basic sanity checks 

if [ ! -e "$_source_file" ]; then
  echo "ERROR! Source file does not exists on path '$_source_file'." >&2
  exit 1
fi

if [ ! -d "$_backup_dir" ]; then
  echo "ERROR! Backup directory does not exists on path '$_backup_dir'." >&2
  exit 1
fi

if [ "$_compress" = 't' -a -z "$(which $_compression_tool)" ]; then
  echo "WARNING! Compression required and compression tool '$_compression_tool' not present in PATH '$PATH'." >&2
  _compress='f'
fi 

if [ -z "$(which openssl)" ]; then
  echo "ERROR! OpenSSL not present in PATH '$PATH'." >&2
  exit 1
fi

if [ -z "$_openssl_pass" ]; then
  echo "ERROR! Unable to encrypt with empty pass argument" >&2
  exit 1
fi

#########################################################
#                                                       #
# Actual script                                         #
#                                                       #
#########################################################

# extract actual file name from _source_file path

_file_name="$(basename $_source_file)"

_dest_file_name="$_file_name.bcp.$(date +%Y-%m-%d-%H-%M-%S)"

# copy file to backup directory

cp $_source_file "$_backup_dir/$_dest_file_name"

# compress file before backing it up

if [ "$_compress" = 't' ]; then
  $_compression_tool $_compression_args "$_backup_dir/$_dest_file_name" > "$_backup_dir/$_dest_file_name$_compressed_suffix"
  rm "$_backup_dir/$_dest_file_name"
  _dest_file_name="$_dest_file_name$_compressed_suffix"
fi

# encrypt file

openssl enc -aes-256-cbc -in "$_backup_dir/$_dest_file_name" -out "$_backup_dir/$_dest_file_name.enc" -pass $_openssl_pass -e -a

if [ "$?" != "0" ]; then
  echo "ERROR! Encryption failed!" >&2
  exit 1
fi

# delete unecrypted original

rm $_backup_dir/$_dest_file_name

# remove older backups 

if [ "$_remove_older" = "t" ]; then
  if [ -n "$(find $_backup_dir -maxdepth 1 -type f -mtime +$_max_age)" ]; then
    echo "Cleaning old backup files ($(find $_backup_dir -maxdepth 1 -type f -mtime +$_max_age | wc -l))"
    find $_backup_dir -maxdepth 1 -type f -mtime +$_max_age | sed 's/\(.*\)/  \1/'
    find $_backup_dir -maxdepth 1 -type f -mtime +$_max_age -delete
  fi
fi
