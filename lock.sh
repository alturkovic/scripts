#!/bin/bash

# Lock PID based

_lock_file_key=

_basename=$(basename $0)

lock() {
  if [ "$#" -eq "0" ]; then
    _lock_file_key=$_basename
  else
    _lock_file_key=$1
  fi

  if [ -e "/tmp/${_lock_file_key}.lock" ]; then
    kill -0 $(cat /tmp/${_lock_file_key}.lock) 2>/dev/null
    if [ "$?" -eq "0" ]; then
      echo "PID $(cat /tmp/${_lock_file_key}.lock) is still running!" >&2
      exit
    else
      echo "PID file exists but no such process $(cat /tmp/${_lock_file_key}.lock)!" >&2
    fi
  fi
  echo $$ > /tmp/${_lock_file_key}.lock
}

release() {
  if [ "$#" -eq "0" ]; then
    _lock_file_key=$_basename
  else
    _lock_file_key=$1
  fi

  if [ -e "/tmp/${_lock_file_key}.lock" ]; then
    rm "/tmp/${_lock_file_key}.lock"
  fi
}
