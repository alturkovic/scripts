#!/bin/bash

_external_push_script=
_file_pattern=
_source_directory=
_port=
_lock_name=
_configuration_file=
_destination_configuration=()

source $(dirname $0)/lock.sh # update to match your lock.sh location

usage() {
  echo """
  Push files matching a pattern to multiple locations using the provided push script.
  
  Usage $0 [options] 'first_destination_configuration' 'second_destination_configuration' '...'
  hosts         host list
  users         user list
  directories   directory list

  x_destination_configuration is expected to be formatted like:
  user host destination_directory

  External push script MUST have 'push' method. Arguments supplied are:
  $1: _source_directory
  $2: _file 
  $3: _user
  $4: _host
  $5: _target_absolute_dir
  $6: _port

  Options:
    -s          external script to use to push a file
    -f          file pattern to scan
    -d          base directory
    -p          output port
    -l          unique lock name (OPTIONAL) 
    -c          configuration file (OPTIONAL)
    -h          help

  Examples:
  ./multi-push.sh -s '/opt/scripts/scp.sh' -f '*.txt' -d '/tmp/text-files/' 'user1 host1 /tmp/' 'user2 host2 /tmp/other/'
  ./multi-push.sh -s '/opt/scripts/scp.sh' -f '*.txt' -d '/tmp/text-files/' -c destination.conf
""" >&2
}

while getopts ":s:f:d:p:l:c:h" _opt; do
  case ${_opt} in
    s )
      _external_push_script=$OPTARG
      ;;
    f )
      _file_pattern=$OPTARG
      ;;
    d )
      _source_directory=$OPTARG
      ;;
    p )
      _port=$OPTARG
      ;;
    l )
      _lock_name=$OPTARG
      ;;
    c )
      _configuration_file=$OPTARG
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

# sanity check script and load it
[ -z "$_external_push_script" ] && echo "ERROR: External push script not defined" && exit 1
[ ! -e "$_external_push_script" ] && echo "ERROR: External push script does not exist" && exit 1
[ ! -f "$_external_push_script" ] && echo "ERROR: External push script is not a file" && exit 1
[ ! -r "$_external_push_script" ] && echo "ERROR: External push script is not readable" && exit 1

source $_external_push_script

# configuration checks
# append trailing '/' if missing
[[ "$_source_directory" != */ ]] && _source_directory="$_source_directory/"

# read destination arguments from parameters or file
# destination arguments are expected to be formatted like: user host destination_directory

if [ -z "${_configuration_file}" ]; then # configuration file not set, read destinations from arguments
  # remaining arguments
  shift $(expr $OPTIND - 1)

  if [ "$#" -eq "0" ]; then
  	echo "ERROR: Must define configuration file or destination parameters, both are missing" && exit 1
  else
    for _destination_parameter in "$@"; do
      _destination_configuration+=("$_destination_parameter")
      if [ $(echo $_destination_parameter | wc -w) -ne 3 ]; then
      	echo "ERROR: Parameters must consist of 3 parts, look at usage definition: $_destination_parameter" && exit 1 
      fi
    done
  fi
else # configuration file set, read destinations from file
  while read -r _configuration_line; do 
  	_destination_configuration+=("$_configuration_line")
  	if [ $(echo $_configuration_line | wc -w) -ne 3 ]; then
      	echo "ERROR: Parameters must consist of 3 parts, look at usage definition: $_configuration_line" && exit 1 
    fi
  done < $_configuration_file
fi

# try to acquire lock before execution to prevent multiple copies executed at once
lock ${_lock_name}

_total_start=$(date +%s)

echo "Push for '$_source_directory' with pattern '$_file_pattern' started @ $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# see if there is anything to push
# only basenames of the files, not their paths
# this is a bit dangerous with files that have space in their names, but such files are already a bad practice on their own and should be avoided anyway
_files_to_push=($(find "$_source_directory" -maxdepth 1 -type f -name "$_file_pattern" -exec basename {} ';'))
if [ ${#_files_to_push[@]} -gt 0 ]; then

  for _file in "${_files_to_push[@]}"; do
    echo "---------- ${_file} ----------"
    _start=$(date +%s)

    for _dst_config in "${_destination_configuration[@]}"; do
      IFS=" " read _user _host _target_absolute_dir <<< ${_dst_config}

      # append trailing '/' if missing
      [[ "$_target_absolute_dir" != */ ]] && _target_absolute_dir="_target_absolute_dir/"

      # if .success file exists for the file and host, it means that the file was already pushed to that host
      # no need to push it again, skip this host for this file 
      if [ -e "$_source_directory${_file}.${_host}.success" ]; then
        echo -e "\tWARN - Copy skipped for ${_file} @ ${_host} already copied"
        continue
      fi

      push "$_source_directory" "$_file" "$_user" "$_host" "$_target_absolute_dir" "$_port"
     done

    echo -e "\tINFO - Cleaning up ${_file}"

    # verify before cleanup
    _success_count=$(find $_source_directory -maxdepth 1 -type f -name "${_file}.*.success" | wc -l)
    if [ $_success_count -eq 0 ]; then
      # no .success files found, nothing pushed to anyone yet
      echo -e "\t\tINFO - Nothing to clean, $_file was not pushed to any host"
    else      
      if [ "$_success_count" -eq "${#_destination_configuration[@]}" ]; then
      	# found as many .success files as we have configured destinations
        # this means that each configured host received a copy of the file
        echo -e "\t\tINFO - All hosts successful, clearing"
        rm $_source_directory${_file}*
      else
        echo -e "\t\tERROR - Failed to push ${_file} to all hosts"
        # show which hosts didn't receive this file
        for _dst_config in "${_destination_configuration[@]}"; do
          IFS=" " read _user _host _target_absolute_dir <<< ${_dst_config}
          if [ ! -e "${_file}.${_host}.success" ]; then
            echo -e "\t\t\tERROR - Push not complete for ${_file} @ ${_host}"
          fi
        done
      fi
    fi

    _end=$(date +%s)
    _took=$((_end-_start))
    echo "File $_file pushed @ $(date '+%Y-%m-%d %H:%M:%S'), took: ${_took}s"
    echo "--------------------------------------------------------------"
  done

else
  # no files matching the defined pattern were found during this execution
  echo -e "\tINFO - No files found"
fi

# release the lock so next execution can grab it
release ${_lock_name}

_total_end=$(date +%s)
_total_took=$((_total_end-_total_start))

echo "Push for '$_source_directory' finished @ $(date '+%Y-%m-%d %H:%M:%S') took: ${_total_took}s"
echo ""
