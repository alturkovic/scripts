#!/bin/bash

put_file() {
  echo "cd ${_target_absolute_dir}"
  echo "lcd ${_source_directory}"
  echo "put ${_file}"
}

push() {
  if [ -z $1 ]; then echo "Missing source directory"; return 1; else _source_directory="$1"; fi
  if [ -z $2 ]; then echo "Missing file"; return 1; else _file="$2"; fi
  if [ -z $3 ]; then echo "Missing user"; return 1; else _user="$3"; fi
  if [ -z $4 ]; then echo "Missing host"; return 1; else _host="$4"; fi
  if [ -z $5 ]; then echo "Missing target directory"; return 1; else _target_absolute_dir="$5"; fi
  if [ -z $6 ]; then _port=22; else _port="$6"; fi
  if [ -z $7 ]; then _push_batch_script=put_file ; else _push_batch_script=$(read "$7"); fi

  if sftp -oPort=$_port -b <(put_file) ${_user}@${_host}; then
    echo -e "INFO - Push completed for ${_file} @ ${_host}"
    touch $_source_directory${_file}.${_host}.success
  fi
}
