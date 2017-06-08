#!/bin/bash

_size=
_port=22
_verbose=
_retry=1
_wait=
_debug=

_file=
_remote=

_tmp_dir_path=

usage() {
  echo """Usage $0 [options] <source-file> <remote-file>
  source-file     path to source file
  remote-file     SCP format for remote file

  Options:
    -s <size>     split file into smaller pieces
    -p <port>     remote port
    -r <retries>  retries
    -w <seconds>  seconds between retries
    -v            verbose output
    -V            debug output
    -h            help
""" >&2
}

# be nice and clean up
onexit() {
  [ -n "$_tmp_dir_path" -a -e "$_tmp_dir_path" ] && rm -r $_tmp_dir_path/tmp_*
  [ -n "$_tmp_dir_path" -a -e "$_tmp_dir_path" ] && rmdir $_tmp_dir_path
}

trap onexit EXIT

while getopts ":s:p:r:w:hvV" _opt; do
  case ${_opt} in
    s )
      _size=$OPTARG
      ;;
    p )
      _port=$OPTARG
      ;;
    r )
      _retry=$OPTARG
      ;;
    w )
      _wait=$OPTARG
      ;;
    h )
      usage
      exit 0
      ;;
    v )
      _verbose="t"
      ;;
    V )
      _debug="t"
      ;;
    \? )
      echo "Error. Unknown option: -$OPTARG" >&2
      exit 1
      ;;
    : )
      echo "Error. Missing option argument for -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# remaining arguments
shift $(expr $OPTIND - 1)

# verify there is enough arguments
[ "$#" -ne "2" ] && echo "ERROR: Invalid number of parameters" && exit 1

_file=$1
_remote=$2

[ -z "$_size" ] && echo "ERROR: Split size not set" && exit 1

# verify source file

[ ! -e "$_file" ] && echo "ERROR: File '$_file' missing" >&2 && exit 1
[ ! -f "$_file" ] && echo "ERROR: File '$_file' not file" >&2 && exit 1
[ ! -r "$_file" ] && echo "ERROR: File '$_file' not readable" >&2 && exit 1

[ -n "$_verbose" ] && echo "INFO: Source file OK" >&2

# determine SSH for target system
_ssh_spec=${_remote%%:*}

[ -n "$_debug" ] && echo "DEBUG: SSH spec: '$_ssh_spec'" >&2
[ -n "$_debug" ] && echo "DEBUG: Testing ssh connectivity" >&2

if ! ssh ${_ssh_spec} true 2>/dev/null ; then
  echo "ERROR: Failed to connect to '$_ssh_spec'" >&2 && exit 1
fi;

# prepare local file for move and split

_tmp_dir_path="/tmp/$$"

[ -n "$_verbose" ] && echo "INFO: Creating temporary directory '$_tmp_dir_path' " >&2
mkdir -p ${_tmp_dir_path}

[ ! -e "$_tmp_dir_path" ] && echo "ERROR: Failed to create temporary directory '$_tmp_dir_path'" >&2 && exit 1

# split source file
[ -n "$_verbose" ] && echo "INFO: Preparing source file for split copy" >&2

cd ${_tmp_dir_path} && split -b ${_size} "$(realpath ${_file})" "tmp_$(basename ${_file})_"
[ "$?" -ne "0" ] && echo "ERROR: Failed to split source file '$_file'" >&2 && exit 1
[ -n "$_debug" ] && ls -l ${_tmp_dir_path}

# ready to copy to remote

_r_file_spec=${_remote##*:}
[ -n "$_debug" ] && echo "DEBUG: Remote file spec '$_r_file_spec'" >&2

_r_dir_name=$(dirname ${_r_file_spec})
[ -n "$_debug" ] && echo "DEBUG: Remote dirname '$_r_dir_name'" >&2

# check if there is something already copied over
[ -n "$_debug" ] && echo "DEBUG: Local shasum" >&2 && cd ${_tmp_dir_path} && sha1sum "tmp_$(basename ${_file})_"* && echo ""
[ -n "$_debug" ] && echo "DEBUG: Remote shasum" >&2 && cd ${_tmp_dir_path} && sha1sum "tmp_$(basename ${_file})_"* |
  ssh ${_ssh_spec} "cd $_r_dir_name && sha1sum -c --strict - 2>/dev/null" 2>/dev/null && echo ""

_failed_files="$(cd ${_tmp_dir_path} && sha1sum "tmp_$(basename ${_file})_"* |
  ssh ${_ssh_spec} "cd $_r_dir_name && sha1sum -c --strict - 2>/dev/null" 2>/dev/null |
  grep FAILED |
  sed 's/^\(.*\): FAILED.*$/\1/')"

_retry_counter=0
while [ -n "$_failed_files" -a "$_retry_counter" -lt "$_retry" ]; do

  for _f_file in ${_failed_files}; do
    [ -n "$_verbose" ] && echo "INFO: copy $_f_file" >&2

    scp ${_tmp_dir_path}/${_f_file} ${_ssh_spec}:${_r_dir_name}/.

  done

  [ -n "$_debug" ] && ssh ${_ssh_spec} "cd $_r_dir_name && sha1sum tmp_$(basename ${_file})_*  2>/dev/null" 2>/dev/null

  _failed_files="$(cd ${_tmp_dir_path} && sha1sum "tmp_$(basename ${_file})_"* |
    ssh ${_ssh_spec} "cd $_r_dir_name && sha1sum -c --strict - 2>/dev/null" 2>/dev/null |
    grep FAILED |
    sed 's/^\(.*\): FAILED.*$/\1/')"

  [ -n "$_failed_files" ] && echo -e "Failed during copy:\n---\n$_failed_files\n---"

  ((_retry_counter++))

  if [ -n "$_wait" -a -n "$_failed_files" ]; then
    echo "Waiting for $_wait seconds, try $_retry_counter of $_retry"
    sleep "$_wait"
  fi

done

[ -n "$_failed_files" ] && echo "Failed to copy all fragments, unable to join file" >&2 && exit 2

[ -n "$_verbose" ] && echo "Joining files..."
ssh ${_ssh_spec} "cat $_r_dir_name/tmp_$(basename ${_file})_* > $_r_dir_name/$(basename ${_file}) && rm $_r_dir_name/tmp_$(basename ${_file})_*" 2>/dev/null

if [ "$?" -eq "0" ]; then
  echo "SUCCESS" >&2
 exit 0
else
  echo "FAILED" >&2
  exit 2
fi
