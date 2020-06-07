#!/usr/bin/env bash

helper::add_help_option() {
  # shellcheck disable=SC2199
  if [[ "${SHOW_HELP}" == 'true' ]]; then
    print::usage
    exit 0
  fi
}

helper::initialize_remote_settings() {
  local remote_environment="${1}"

  case "${remote_environment}" in

  production)
    SSH_BASE_PATH="${SSH_BASE_PATH_PRODUCTION}"
    REMOTE_DB_PATH="${DB_PRODUCTION}"
    REMOTE_ASSETS_PATH="${ASSETS_PRODUCTION}"
    REMOTE_FILES_PATH="${FILES_PRODUCTION}"
    ;;

  staging)
    SSH_BASE_PATH="${SSH_BASE_PATH_STAGING}"
    REMOTE_DB_PATH="${DB_STAGING}"
    REMOTE_ASSETS_PATH="${ASSETS_STAGING}"
    REMOTE_FILES_PATH="${FILES_STAGING}"
    ;;

  *)
    l::log_and_show_usage_and_exit 1 \
      'ERROR' \
      "Target '${remote_environment}' environment is not supported, use [production,staging]"
    ;;
  esac

  ssh_resource=(${SSH_BASE_PATH//:/ })
  REMOTE_URL="${ssh_resource[0]}"
  REMOTE_PROJECT_PATH="${ssh_resource[1]}"

  local required_settings=$(
    cat <<-HEREDOC
    | SSH_BASE_PATH       = '${SSH_BASE_PATH}'
    | REMOTE_DB_PATH      = '${REMOTE_DB_PATH}'
    | REMOTE_ASSETS_PATH  = '${REMOTE_ASSETS_PATH}'
    | REMOTE_FILES_PATH   = '${REMOTE_FILES_PATH}'
    | REMOTE_URL          = '${REMOTE_URL}'
    | REMOTE_PROJECT_PATH = '${REMOTE_PROJECT_PATH}'
HEREDOC
  )

  if [[ -z "${SSH_BASE_PATH}" ]] || [[ -z "${REMOTE_URL}" ]] || [[ -z "${REMOTE_PROJECT_PATH}" ]]; then
    l::log_and_show_usage_and_exit 1 'ERROR' "Required settings are missing\n\n${required_settings}"
  fi

  if [[ "${DEBUG}" == 'true' ]]; then
    l::log 'INFO' "Required settings:\n\n${required_settings}\n"
  fi
}

helper::get_index() {
  local search="${1}"
  local elements_name=$2[@]
  local elements=("${!elements_name}")
  local result=''

  for index in "${!elements[@]}"; do

    if [[ "${elements[$index]}" == "${search}" ]]; then
      result="${index}"
      break
    fi

  done

  echo "${result}"
}

helper::get_element() {
  local index="${1}"
  local elements_name=$2[@]
  local elements=("${!elements_name}")
  echo "${elements[${index}]}"
}

helper::string_replace() {
  local variable="${1}"
  shift
  # shellcheck disable=SC2059
  printf -v "${variable}" "${@}"
}
