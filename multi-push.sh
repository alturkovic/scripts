#!/bin/bash

_options=":h:u:d:l:H"

_dest_hosts=
_users=
_target_dirs=
_lock_name=
_file_pattern=

usage() {
  echo """Usage $0 [options] <file-pattern>

  ################

  WARNING: Order of parameters matters! Host, user and directory parameters are matched by index as one

  example: ./multi-push.sh -h tc01.lab.biss.hr -u tc01 -d /tmp/tc01_temp_dir -h tc02.lab.biss.hr -u tc02 -d /tmp/tc02_temp_dir \"*txt\"

  ################

  file-pattern              pattern to find files (enclose in double-quotes)

  Options:
    -h                      destination host
    -u                      user for ssh
    -d                      directory to push
    -l                      lock name
    -H                      help
""" >&2
}

while getopts $_options _option; do
  case $_option in 
    h )
      _dest_hosts+=($OPTARG)
      ;;
    u )
      _users+=($OPTARG)
      ;;
    d )
      _target_dirs+=($OPTARG)
      ;;
    l )
      _lock_name=$OPTARG
      ;;
    H )
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
[ "$#" -ne "1" ] && echo "ERROR: Invalid number of parameters: $#" && exit 1

_file_pattern=$1

# test if configured correctly 

[ -z "$_dest_hosts" ] && echo "ERROR: Missing destinations configuration" && exit 1
[ -z "$_users" ] && echo "ERROR: Missing users configuration" && exit 1
[ -z "$_target_dirs" ] && echo "ERROR: Missing target directories configuration" && exit 1

[ ${#_dest_hosts[@]} -ne ${#_users[@]} -a ${#_dest_hosts[@]} -ne ${#_target_dirs[@]} ] && echo "ERROR: Size of configuration arrays does not match" && exit 1

[ -z "$_lock_name" ] && _lock_name=$0_$$

# options all set, ready to go

_dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

cd $_dir

echo "Push for '$_dir' started @ $(date '+%Y-%m-%d %H:%M:%S')" 

_total_start=$(date +%s)

source lock.sh

lock $_lock_name

# see if there is anything to push

if [ "$(find . -iname "$_file_pattern" | wc -l)" -gt "0" ]; then

  # for each file
  for _file in $_file_pattern; do
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
      scp $_file ${_user}@${_host}:${_target_absolute_dir}/${_file}.tmp

      if [ "$?" -eq "0" ]; then
        echo -e "\tINFO - Copy successful for ${_file} @ ${_host}, removing .tmp extension"
  
        # remove temporary extension
        ssh -l ${_user} ${_host} "mv ${_target_absolute_dir}/${_file}.tmp ${_target_absolute_dir}/${_file}"
          
        if [ "$?" -eq "0" ]; then
          # mark as success
          echo -e "\tINFO - Push succesful for ${_file} @ ${_host}"
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
     _success_count=$(ls ${_file}.*.success 2>/dev/null | wc -l)
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

release $_lock_name

_total_end=$(date +%s)
_total_took=$((_total_end-_total_start))

echo "Push for '$_dir' finished @ $(date '+%Y-%m-%d %H:%M:%S') took: ${_total_took}s "
echo ""

