#!/usr/bin/env bash

# Copyright 2024 HCL America, Inc

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -Eeuo pipefail
IFS=$'\n\t'
trap cleanup SIGINT SIGTERM ERR EXIT

semaphore_subdir=semaphore
ansible_playbook=/repo/semaphore/semaphore.yml

# Container parameters
sempahore_container=semaphore
mysql_volume=semaphore-mysql

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
script_filename=$(basename "${BASH_SOURCE[0]}")
script_basename=${script_filename%.*}
logFile="${script_dir}/${script_basename}.log"
envFile="${script_dir}/${semaphore_subdir}/.env"

# Set default values for user parameters.
# The values can be changed by using flags when launching the program.
verbose=0
log=0
NO_COLOR=

# ----- Usage -----

usage() {
  cat <<EOF
Usage:   $script_filename [OPTIONS] COMMAND [server]
Example:
  $script_filename --help
  $script_filename start
  $script_filename check alpha.example.com
  $script_filename -lv create alpha.example.com
  $script_filename info
  $script_filename delete alpha.example.com
  $script_filename stop
  $script_filename reset

Manages a Semaphore container running HCL Domino server tasks.

Options:
  -h, --help      Print this help and exit
  -l, --log       Log messages to a file
  -v, --verbose   Verbose output (-v, -vv, -vvv)

Available commands:
  start           Start a Semaphore container
  check           Check the configuration parameters for Domino tasks
  create          Create tasks for a Domino installation
  info            Prints Semaphore container status and connection info
  delete          Delete tasks for a Domino installation
  stop            Stop a Semaphore container
  reset           Semaphore container factory reset; removes tasks and history

EOF
  # exit
}

info() {
  local info_text="
${GREEN}Connect to Sempahore${NOFORMAT} - execute the scripts:
  URL:        ${YELLOW}http://localhost:${SEMAPHORE_PORT}/${NOFORMAT}
  username:   ${YELLOW}${SEMAPHORE_ADMIN_NAME}${NOFORMAT}
  password:   ${YELLOW}${SEMAPHORE_ADMIN_PASSWORD}${NOFORMAT}
"

  echo -e "${info_text}"
}

read_ini() {
# shellcheck source=./semaphore/.env
  source "${envFile}"
}

# ----- Supporting functions - generic -----

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m'
    PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m' LIGHTGRAY='\033[0;37m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW='' LIGHTGRAY=''
  fi
}

log_msg() {
  local message="${1-}"
  local severity="${2:-NORMAL}"

  case $severity in
  ERROR | RED)
    local color="RED"
    ;;
  WARNING | YELLOW)
    local color="YELLOW"
    ;;
  SUCCESS | GREEN)
    local color="GREEN"
    ;;
  ACTION | BLUE)
    local color="BLUE"
    ;;
  VERBOSE | LIGHTGRAY)
    local color="LIGHTGRAY"
    ;;
  NORMAL | NOFORMAT)
    local color="NOFORMAT"
    ;;
  *)
    local color="NOFORMAT"
    ;;
  esac

  echo >&2 -e "${!color}${message}${NOFORMAT}"

  if [[ $log == 1 ]]; then
    echo "$(date) [${severity}] ${FUNCNAME[2]-} ${message}" >>"$logFile"
  fi
}

msg() {
  log_msg "${1:-}"
}

succ() {
  log_msg "${1:-}" "SUCCESS"
}

action() {
  log_msg "\n${1:-}" "ACTION"
}

warn() {
  log_msg "${1:-}" "WARNING"
}

error() {
  log_msg "\n${1:-}\n" "ERROR"
}

verbose() {
  [[ $verbose -gt 0 ]] && log_msg "${1:-}" "VERBOSE"
  return 0
}

die() {
  local message=$1
  [ -z "$message" ] && message="Died"
  local code=${2-1} # if not specified as a second parameter, exit code 1 is used
  echo -e "$message (at ${BASH_SOURCE[1]}:${FUNCNAME[1]} line ${BASH_LINENO[0]})"
  exit "$code"
}

# ----- Supporting functions - special -----

parse_params() {
  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose)
      verbose=$((verbose + 1)) # Each -v adds 1 to verbosity.
      ;;
    -l | --log)
      log=1
      ;;
    -[hvl][!-]*)
      set -- "${1:0:2}" "-${1:2}" "${@:2}"
      continue
      ;;
    --no-color) NO_COLOR=1 ;;
    --)
      shift
      break
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  return 0
}

parse_args() {
  if [ $# -eq 0 ]; then
    error "Missing arguments: No command specified."
    usage
    exit 1
  fi

  if [ $# -gt 2 ]; then
    error "Too many arguments."
    usage
    exit 1
  fi

  command=$1
  server=${2-}
  verbose "command = ${command}"
  verbose "server (optional) = ${server}"

  if [ $verbose -gt 0 ]; then
    verbose_string="-"
    for ((i = 0; i < verbose; i++)); do
      verbose_string+="v"
    done
  else
    verbose_string=""
  fi

  verbose "verbose string = ${verbose_string}"

  if [[ (${command} == "create" || ${command} == "delete" || ${command} == "check") &&
    (-z ${server}) ]]; then
    error "Missing server name (when COMMAND is 'create', 'delete', or 'check')"
    usage
    exit 1
  fi
}

docker_info() {
  verbose "Checking docker environment"

  docker compose version &>/dev/null

  if [ $? -eq 0 ]; then
    verbose "Docker Compose is installed."
  else
    error "Docker Compose is not installed."
    msg "Please install Docker (with Docker Compose)."
    exit 1
  fi

  container_id="$(docker-compose ps -a -q ${sempahore_container})"

  if [[ -z "${container_id}" ]]; then
    verbose "The Semaphore container is not running."
  else
    verbose "Semaphore container ID: ${container_id}"
    container_status=$(docker inspect --format "{{.State.Status}}" "${container_id}")
    verbose "Sempahore container status: ${container_status}"
  fi

  return 0
}

# ----- Executive functions -----

start_semaphore() {
  action "STARTING Semaphore container"

  docker compose up -d

  succ "The Semaphore container started."

  return 0
}

stop_semaphore() {
  action "STOPPING Semaphore container"

  docker compose down

  return 0
}

check_semaphore() {
  action "CHECK server ${server}"

  docker compose exec "${sempahore_container}" ansible-playbook ${verbose_string} \
    -e server="${server}" \
    -e role_start=assert \
    "${ansible_playbook}"

  return 0
}

create_records() {
  action "CREATING RECORDS FOR SERVER ${server}"

  docker compose exec "${sempahore_container}" ansible-playbook ${verbose_string} \
    -e server="${server}" \
    "${ansible_playbook}"

  succ "The records for server ${server} were successfully created."

  return 0
}

info_semaphore() {
  action "INFO about Semaphore"

  if [[ -z "${container_id}" ]]; then
    error "The Semaphore container is not running"
    msg "Start the container with a command: ./${script_filename} start"
    exit 1
  else
    msg "Sempahore container status: ${YELLOW}${container_status}${NOFORMAT}"
  fi

  case $container_status in
  running)
    info
    ;;
  exited)
    error "The Semaphore container is not started."
    msg "Start the container with a command: ./${script_filename} start"
    ;;
  *)
    error "Unknown container status"
    exit 1
    ;;
  esac

  return 0
}

delete_records() {
  action "DELETE records for ${server}"

  msg "Records for server ${server} will be removed. You can recreate them later."
  read -r -p "Are you sure? [y/N]" -n 1
  msg
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    verbose "Deletion confirmed."

    docker compose exec "${sempahore_container}" ansible-playbook ${verbose_string} \
      -e server="${server}" \
      -e role_start=delete \
      "${ansible_playbook}"
  fi

  succ "The records for server ${server} were successfully deleted."

  return 0
}

reset_semaphore() {
  action "RESET Semaphore"

  stop_semaphore

  verbose "Removing Docker volume ${semaphore_subdir}_${mysql_volume}."
  docker volume rm "${semaphore_subdir}_${mysql_volume}" &>/dev/null || true

  succ "All containers were successfully removed and data volumes deleted."
  msg "You can now start the container and create new records."

  return 0
}

# ----- Main script -----

if [ $# -eq 0 ]; then
  usage
  exit 0
fi

read_ini

parse_params "$@"

setup_colors

parse_args "${args[@]}"

cd $semaphore_subdir

docker_info

case "${command}" in
start)
  start_semaphore
  docker_info
  info_semaphore
  ;;
stop)
  stop_semaphore
  ;;
check)
  check_semaphore
  ;;
create)
  create_records
  info_semaphore
  ;;
info)
  info_semaphore
  ;;
delete)
  delete_records
  ;;
reset)
  reset_semaphore
  ;;
*)
  error "Command not recognized."
  usage
  ;;
esac
