#!/bin/bash

_dest_hosts=( )
_users=( )
_target_dirs=( )
_lock_name=
_file_pattern=

_dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

cd ${_dir}

echo "Push for '$_dir' started @ $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

_total_start=$(date +%s)

source lock.sh # update to match your lock.sh location

usage() {
  echo """Usage $0 [options] '<hosts>' '<users>' '<directories>'
  hosts         host list
  users         user list
  directories   directory list

  Options:
    -l          unique lock name
    -p          file pattern to scan
    -h          help
""" >&2
}

while getopts ":l:p:h" _opt; do
  case ${_opt} in
    l )
      _lock_name=$OPTARG
      ;;
    p )
      _file_pattern=$OPTARG
      ;;
    h )
      usage
      exit 0
      ;;
    \? )
      echo "Error. Unknown option: -$OPTARG"
      exit 1
      ;;
    : )
      echo "Error. Missing option argument for -$OPTARG"
      exit 1
      ;;
  esac
done

# remaining arguments
shift $(expr $OPTIND - 1)

# verify there is enough arguments
[ "$#" -ne "3" ] && echo "ERROR: Invalid number of parameters" && exit 1

IFS=' ' read -r -a _dest_hosts <<< $1
IFS=' ' read -r -a _users <<< $2
IFS=' ' read -r -a _target_dirs <<< $3

if [ ${#_dest_hosts[@]} -eq "0" ]; then
  echo "Not configured correctly, empty host list"
  exit 1
fi

if [ ${#_dest_hosts[@]} -ne ${#_users[@]} -o ${#_dest_hosts[@]} -ne ${#_target_dirs[@]} ]; then
  echo "Size of configuration arrays does not match"
  exit 1
fi

lock ${_lock_name}

# see if there is anything to push
_files_to_push=(`find ./ -maxdepth 1 -name "${_file_pattern}"`)
if [ ${#_files_to_push[@]} -gt "0" ]; then

  # for each file
  for _file in "${_files_to_push[@]}"; do
    echo "--------------------------------------------------------------"
    echo "Push file $_file @ $(date '+%Y-%m-%d %H:%M:%S')"
    _start=$(date +%s)

    # for _host in ${_dest_hosts[@]}; do
    for (( _idx=0 ; _idx < ${#_dest_hosts[@]} ; _idx++ )); do
      _host=${_dest_hosts[$_idx]}
      _user=${_users[$_idx]}
      _target_absolute_dir=${_target_dirs[$_idx]}

      echo -e "\tINFO - Pushing ${_file} to ${_host}"

      if [ -e "${_file}.${_host}.success" ]; then
        echo -e "\tWARN - Copy skipped for ${_file} @ ${_host} already copied"
        continue
      fi

      # copy as temporary
      scp ${_file} ${_user}@${_host}:${_target_absolute_dir}/${_file}.tmp
      _ret=$?

      if [ "$_ret" -eq "0" ]; then
        echo -e "\tINFO - Copy successful for ${_file} @ ${_host}, removing .tmp extension"

        # remove temporary extension
        ssh -l ${_user} ${_host} "mv ${_target_absolute_dir}/${_file}.tmp ${_target_absolute_dir}/${_file}"
        _ret=$?

        if [ "$_ret" -eq "0" ]; then
          # mark as success
          echo -e "\tINFO - Push successful for ${_file} @ ${_host}"
          touch ${_file}.${_host}.success
        else
          echo -e "\t\tERROR - Rename failed for ${_file} @ ${_host}"
        fi

      else
        echo -e "\t\tERROR - Copy failed for ${_file} @ ${_host}"
      fi
    done

    echo -e "\tINFO - Cleaning up ${_file}"

    # verify before cleanup
    _success_count=$(ls ${_file}.*.success | wc -l)
    if [ "$_success_count" -eq "${#_dest_hosts[@]}" ]; then
      echo -e "\t\tINFO - All hosts successful, clearing"
      rm ${_file}*
    else
      echo -e "\t\t\tERROR - Failed to push ${_file} to all hosts"
      # show what has failed
      for _host in ${_dest_hosts[@]}; do
        if [ ! -e "${_file}.${_host}.success" ]; then
          echo -e "\t\t\t\tERROR - Push not complete for ${_file} @ ${_host}"
        fi
      done
    fi

    _end=$(date +%s)
    _took=$((_end-_start))
    echo "Push file $_file @ $(date '+%Y-%m-%d %H:%M:%S') took: ${_took}s"
    echo "--------------------------------------------------------------"
  done

else
  # just say OK
  echo -e "\tINFO - No files found"
fi

release ${_lock_name}

_total_end=$(date +%s)
_total_took=$((_total_end-_total_start))

echo "Push for '$_dir' finished @ $(date '+%Y-%m-%d %H:%M:%S') took: ${_total_took}s "
echo ""
