#!/bin/bash
which jq > /dev/null
if [ $? -gt 0 ]
then
  echo "install jq https://stedolan.github.io/jq/"
  exit 1
fi

max_file_count=6
workflow_dir=`dirname $0`

usage_and_exit()
{
  read -d '' usage << USAGE
usage: workflow.stress.sh -n files_per_folder [-hvp] [-d seconds]
  -N number of folders to generate (default 3, see workflow.sprawl.sh for details)
  -n required. number of files to put in project, and all child folders
  -h display this message
  -v verbose output
  -p pretend mode, do not hit the server
  -f force script to run when more than ${max_file_count} files are provided. Also runs workflow.sprawl.command with -f.
  -d delay (in seconds) between server calls. (default: 1)

Requires DDSTOKEN to be set to a valid api token and DDSURL to be
set to the appropriate api url.
USAGE
  if [ -n "$1" ] && [ $1 -gt 0 ]
  then
    echo "${usage}" >&2
    exit $1
  else
    echo "${usage}"
    exit 0
  fi
}

verbose_echo()
{
  $verbose && echo $1 >&2
}

crud_command()
{
  local crud_op=$1
  local url=$2
  local payload=$3
  verbose_echo "${crud_op} ${url} ${payload}"
  if ! $pretend
  then
    sleep $delay
    $verbose && set -o verbose
    curl_progress="s"
    $verbose && curl_progress="#"
    response=$(curl --insecure -${curl_progress} -X ${crud_op} --header 'Content-Type: application/json' --header 'Accept: application/json' --header "Authorization: ${auth_token}" -d "${payload}" "${url}")
    if [ $? -gt 0 ]
    then
      echo "Problem!"
      exit 1
    fi
    $verbose && set +o verbose
    $verbose && echo ${response} | jq
    error=`echo ${response} | jq '.error'`
    if [ "${error}" != null ]
    then
      echo "Problem!"
      exit 1
    fi
  fi
}

get_command()
{
  local url=$1
  verbose_echo "GET ${url}"
  if ! $pretend
  then
    sleep $delay
    $verbose && set -o verbose
    curl_progress="s"
    $verbose && curl_progress="v"
    response=$(curl --insecure -${curl_progress} --header 'Content-Type: application/json' --header 'Accept: application/json' --header "Authorization: ${auth_token}" "${url}")
    if [ $? -gt 0 ]
    then
      echo "Problem!"
      exit 1
    fi
    $verbose && set +o verbose
    $verbose && echo ${response} | jq
    error=`echo ${response} | jq '.error'`
    if [ "${error}" != null ]
    then
      echo "Problem!"
      exit 1
    fi
  fi
}

get_id_from_response()
{
  harvest_response '.id'
}

harvest_response()
{
  local jq_input=$1
  if $pretend
  then
    echo "P-`uuidgen`"
  else
    echo ${response} | jq -r "${jq_input}"
  fi
}

upload_to_parent()
{
  local parent_kind=$1
  local parent_id=$2
  current_file_number=1
  while [ ${current_file_number} -le ${files_per_folder} ]
  do
    verbose_echo "file ${current_file_number}"
    upload_command="${workflow_dir}/upload_file.sh"
    if ${pretend}
    then
      upload_command="${upload_command} -p"
    fi
    upload_command="${upload_command} ${workflow_dir}/chunk1.txt ${parent_kind} ${parent_id}"
    $upload_command
    (( current_file_number += 1 ))
  done
}

verbose=false
pretend=false
force=false
delay=1
folder_count=3
files_per_folder=0
while getopts ":hvpfN:d:n:" opt; do
  case $opt in
    h)
      usage_and_exit
      ;;
    v)
      verbose=true
      ;;
    p)
      pretend=true
      ;;
    f)
      force=true
      ;;
    d)
      if [ "$OPTARG" -ge 0 ]
      then
        delay=$OPTARG
      else
        echo "Delay must be a positive integer" >&2
        exit 1
      fi
      ;;
    N)
      if [ "$OPTARG" -gt 0 ]
      then
        folder_count=$OPTARG
      else
        echo "folder_count must be a positive integer" >&2
        exit 1
      fi
      ;;
    n)
      files_per_folder=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Shift options off parameters
shift $((OPTIND-1))

if [ ${files_per_folder} -lt 1 ]
then
  echo "files_per_folder must be a positive integer greater than 0" >&2
  usage_and_exit 1
elif [ ${files_per_folder} -gt ${max_file_count} ] && ! $force
then
  echo "Too many files, ${max_file_count} is the max." >&2
  usage_and_exit 1
fi

verbose_echo "Verbose output"
$pretend && verbose_echo "Running in pretend mode"
verbose_echo "Delay set to $delay"

auth_token=$DDSTOKEN
if [ -z ${auth_token} ]
then
  echo "DDSTOKEN is empty."
  exit 1
fi
verbose_echo "Using token: [${auth_token}]"

dds_url=$DDSURL
if [ -z $dds_url ]
then
  echo "DDSURL is empty."
  exit 1
fi
verbose_echo "Using url: [${dds_url}]"

activity_start=`date "+%Y-%m-%dT%H:%M:%S%z"`
activity_name="Stress ${activity_start}"
activity_desc="Activity created by workflow.stress.sh on `date`"
verbose_echo "Creating Activity"
crud_command 'POST' "${dds_url}/api/v1/activities" "{\"name\":\"${activity_name}\",\"description\":\"${activity_desc}\",\"started_on\":\"${activity_start}\"}"
activity_id=$(get_id_from_response)

sprawl_command="${workflow_dir}/workflow.sprawl.sh"
if ${pretend}
then
  sprawl_command="${sprawl_command} -p"
fi

if ${force}
then
  sprawl_command="${sprawl_command} -f"
fi

this_folder=0
while [ ${this_folder} -lt ${folder_count} ]
do
  sprawl_command="${sprawl_command} stress-`uuidgen`"
  (( this_folder += 1 ))
done

verbose_echo "Running ${sprawl_command}"
project_id=`${sprawl_command} 2>&1 | awk '{print $NF}'`
if [ $? -gt 0 ]
then
  echo "Sprawl quit unexpectedly!"
  exit 1
fi
verbose_echo "Creating files in Project ${project_id} root"
upload_to_parent 'dds-project' ${project_id}

get_command "${dds_url}/api/v1/projects/${project_id}/children?name_contains="
for folder_id in `harvest_response '.results[] | select(.kind == "dds-folder") | .id'`
do
  verbose_echo "creating files in dds-folder ${folder_id}"
  upload_to_parent 'dds-folder' ${folder_id}

  get_command "${dds_url}/api/v1/folders/${folder_id}/children"
  for file_version_id in `harvest_response '.results[] | select(.kind == "dds-file") | .current_version.id'`
  do
    verbose_echo "${file_version_id} wasGeneratedBy ${activity_id}"
    crud_command 'POST' "${dds_url}/api/v1/relations/was_generated_by" "{\"activity\":{\"id\":\"${activity_id}\"},\"entity\":{\"kind\":\"dds-file-version\",\"id\":\"${file_version_id}\"}}"
  done
done

activity_end=`date "+%Y-%m-%dT%H:%M:%S%z"`
crud_command 'PUT' "${dds_url}/api/v1/activities/${activity_id}" "{\"ended_on\":\"${activity_end}\"}"

get_command "${dds_url}/api/v1/current_user/usage"
echo "{\"usage\":${response},"
get_command "${dds_url}/api/v1/projects/${project_id}/children?name_contains="
echo "\"children\":${response}}"
