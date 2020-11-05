#!/usr/bin/env bash
set -e
set -o pipefail

readonly SCRIPT_PATH="$(dirname "${0}")"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly ENVIRONMENT_FILEPATH="$(pwd)/.env"
readonly ARGS="${@}"

SUPPORTED_ENVIRONMENTS=('staging' 'production')
IS_BACKUP_DUMP='true'
HIDE_TITLE='false'
HIDE_RESULT_BANNER='false'
HIDE_BACKUP_OUTPUT='false'

__USAGE_MESSAGE=$(
  cat <<-HEREDOC
  USAGE: ${SCRIPT_NAME} {--skip-db-dump} {--debug} {--dry-run}

  Options:
      --help                  show usage
      --no-backup             stores db dump in root of .db"
      --debug                 show verbose messages"
      --dry-run               don\'t execute fetch"
      --hide-title            hides script title
      --hide-result-banner   hides the backup file result banner
      --hide-backup-output    hides \'wp db export\' output
HEREDOC
)

source "${SCRIPT_PATH}/library/default-options.sh"
source "${SCRIPT_PATH}/library/print.sh"
source "${SCRIPT_PATH}/library/logging.sh"
source "${SCRIPT_PATH}/library/helper.sh"
source "${SCRIPT_PATH}/library/remote-command-composer.sh"

# shellcheck disable=SC2199
if [[ "${@}" == *'--no-backup'* ]]; then
  IS_BACKUP_DUMP="false"
fi

# shellcheck disable=SC2199
if [[ "${@}" == *'--hide-title'* ]]; then
  HIDE_TITLE="true"
fi

# shellcheck disable=SC2199
if [[ "${@}" == *'--hide-result-banner'* ]]; then
  HIDE_RESULT_BANNER="true"
fi

# shellcheck disable=SC2199
if [[ "${@}" == *'--hide-backup-output'* ]]; then
  HIDE_BACKUP_OUTPUT="true"
fi

if [[ "${HIDE_TITLE:-false}" == 'false' ]]; then
  print::title "Dump DB"
fi
helper::add_help_option
l::log_default_options

if [[ ! -f "${ENVIRONMENT_FILEPATH}" ]]; then
  l::log_and_show_usage_and_exit 1 'ERROR' "${ENVIRONMENT_FILEPATH} file missing"
fi

export $(grep -v '#.*' .env | xargs)

SSH_BASE_PATH=''
REMOTE_DB_PATH=''
REMOTE_ASSETS_PATH=''
REMOTE_FILES_PATH=''
REMOTE_URL=''
REMOTE_PROJECT_PATH=''

helper::initialize_remote_settings "${WP_ENV}"

if [[ "${IS_BACKUP_DUMP}" == "false" ]]; then
  REMOTE_DB_PATH=".db"
else
  REMOTE_DB_PATH=".db/backup"
fi

target_environment="${WP_ENV:-development}"
db_dump_filename="${target_environment}_$(date "+%Y%m%d-%H%M%S").sql"
db_dump_sub_file_path="${REMOTE_DB_PATH}/${db_dump_filename}"

db_dump_path="${REMOTE_PROJECT_PATH}/$(dirname "${db_dump_sub_file_path}")"
if [[ ! -d "${db_dump_path}" ]]; then
  l::log_and_show_usage_and_exit 1 'ERROR' "db dump path '${db_dump_path}' does not exists"
fi

db_dump_file_path="${REMOTE_PROJECT_PATH}/${db_dump_sub_file_path}"
db_dump_command="wp db export ${db_dump_file_path} --add-drop-table %s;"

if [[ "${HIDE_BACKUP_OUTPUT:-false}" == 'true' ]]; then
  helper::string_replace "db_dump_command" "${db_dump_command}" ">/dev/null"
else
  helper::string_replace "db_dump_command" "${db_dump_command}"
fi

if [[ "${DEBUG:-false}" == 'true' ]]; then
  print::command "${db_dump_command}"
fi

if [[ "${DRY_RUN:-false}" == 'false' ]]; then
  eval "${db_dump_command}"
fi

if [[ "${HIDE_RESULT_BANNER:-false}" == 'false' ]]; then
  echo ''
  echo '  //////////////////////////////////////////////////////'
  echo "  db: '${db_dump_sub_file_path}'"
  echo '  //////////////////////////////////////////////////////'
fi

echo ''
