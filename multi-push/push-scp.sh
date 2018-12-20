#!/bin/bash

push() {
  if [ -z $1 ]; then echo "Missing source directory"; return 1; else _source_directory="$1"; fi
  if [ -z $2 ]; then echo "Missing file"; return 1; else _file="$2"; fi
  if [ -z $3 ]; then echo "Missing user"; return 1; else _user="$3"; fi
  if [ -z $4 ]; then echo "Missing host"; return 1; else _host="$4"; fi
  if [ -z $5 ]; then echo "Missing target directory"; return 1; else _target_absolute_dir="$5"; fi
  if [ -z $6 ]; then _port=22; else _port="$6"; fi

  # TODO check if remote file already exists and has the same checksum, just remove .tmp

  # copy as temporary, to prevent the other side from processing unfinished files
  if scp -q -P $_port $_source_directory${_file} ${_user}@${_host}:${_target_absolute_dir}${_file}.tmp; then
    echo -e "\tINFO - Copy successful for ${_file} @ ${_host}, removing .tmp extension"

    # remove temporary extension to mark copy as complete
    if ssh -l ${_user} ${_host} "mv ${_target_absolute_dir}${_file}.tmp ${_target_absolute_dir}${_file}"; then
      # mark as success, next execution will skip this file for this host
      echo -e "\tINFO - Push completed for ${_file} @ ${_host}"
      touch $_source_directory${_file}.${_host}.success
    else
      echo -e "\tERROR - Rename failed for ${_file} @ ${_host}"
    fi

  else
    echo -e "\tERROR - Copy failed for ${_file} @ ${_host}"
  fi
}
