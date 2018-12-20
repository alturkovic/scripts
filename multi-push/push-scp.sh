#!/bin/bash

push() {
  _source_directory=$1
  _file=$2
  _user=$3
  _host=$4
  _target_absolute_dir=$5
  _port=$6

  # copy as temporary, to prevent the other side from processing unfinished files
  if scp -P $_port $_source_directory${_file} ${_user}@${_host}:${_target_absolute_dir}${_file}.tmp; then
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
