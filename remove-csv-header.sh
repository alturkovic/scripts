#!/bin/bash

_prepared_suffix=".prepared"
_temp_suffix=".tmp"
_processing_suffix=".tmp"

_verbose=

_file_pattern=
_source_dir=
_target_dir=

usage() {
	echo """$0 [options] <file-pattern> <source-dir> <target-dir>
	file-pattern	pattern to match files that should be prepared
	source-dir	    directory to scan with <file-pattern>
	target-dir	    directory to put prepared files in

	Options:
	  -s <prepared suffix>	    suffix to put on prepared files
	  -t <temporary suffix>	    suffix to put on temporary output files
	  -p <processing suffix>	suffix to put while processing files
	  -v			            verbose output
	  -h			            help
	""" >&2
}

while getopts ":s:hv" _opt; do
  case ${_opt} in
    s )
      _prepared_suffix=$OPTARG
      ;;
    t )
      _temp_suffix=$OPTARG
      ;;
    p )
      _processing_suffix=$OPTARG
      ;;
    h )
      usage
      exit 0
      ;;
    v )
      _verbose="t"
      ;;
    \? )
      echo "ERROR: Unknown option: -$OPTARG" >&2
      exit 1
      ;;
    : )
      echo "ERROR: Missing option argument for -$OPTARG" >&2
      exit 1
      ;;
  esac
done

[ -z "$_prepared_suffix" ] && echo "ERROR: Prepared suffix not set" && exit 1
[ -z "$_temp_suffix" ] && echo "ERROR: Temporary suffix not set" && exit 1
[ -z "$_processing_suffix" ] && echo "ERROR: Processing suffix not set" && exit 1

# remaining arguments
shift $(expr $OPTIND - 1)

# verify there is enough arguments
[ "$#" -ne "3" ] && echo "ERROR: Invalid number of parameters" && exit 1

_file_pattern=$1
_source_dir=$2
_target_dir=$3

# make sure target dir exists
[ -n "$_verbose" ] && echo "INFO: Creating target directory '${_target_dir}'" >&2
mkdir -p ${_target_dir}

if [ "$?" -ne "0" ]; then
    echo "ERROR: Could not create target directory '${_target_dir}'" && exit 1
fi

_files=($(find ${_source_dir} -name ${_file_pattern} -type f))

echo "INFO: Found files matching '${_file_pattern}': ${_files[*]}" >&2

if [ ${#_files[@]} -ne 0 ]; then
    for _file in "${_files[@]}"; do
        echo "--------------------------------------------------------------" >&2
        _start=$(date +%s)

        _filename=$(basename ${_file})
        _output_file=${_target_dir}/${_filename}${_temp_suffix}
        [ -n "$_verbose" ] && echo "INFO: Preparing file '${_file}'" >&2
        touch ${_output_file}

        if [ "$?" -eq "0" ]; then
            [ -n "$_verbose" ] && echo "INFO: Created file '${_output_file}'" >&2

            _header=$(head -1 ${_file})
            echo ${_header} > ${_output_file}
            [ -n "$_verbose" ] && echo "INFO: Copied header from file '${_file}' to '${_output_file}'" >&2

            tail -n +2 ${_file} > ${_file}${_processing_suffix} && mv -f ${_file}${_processing_suffix} ${_file}

            if [ "$?" -eq "0" ]; then
                [ -n "$_verbose" ] && echo "INFO: Removed header from file '${_file}'" >&2

                _end=$(date +%s)
                _took=$((_end-_start))
                echo "INFO: Prepared file '${_file}' in: ${_took}s" >&2
            else
                echo "ERROR: Could not remove header from file '${_file}'" >&2
            fi
        else
            echo "ERROR: Could not create file '${_output_file}'" >&2
        fi
    done
    echo "--------------------------------------------------------------" >&2
else
    [ -n "$_verbose" ] && echo "INFO: No files found matching pattern '${_file_pattern}' in directory '${_source_dir}'" >&2
fi
echo "INFO: DONE" >&2
