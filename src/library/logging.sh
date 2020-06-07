#!/usr/bin/env bash

l::log() {
  local level="${1:-DEBUG}"
  local message="${2:-message missing}"
  echo -e "  ${level}: ${message}"
}

l::log_default_options() {
  if [[ "${DEBUG}" == "true" ]]; then
    l::log 'INFO' '--debug enabled'
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    l::log 'WARN' '--dry-run enabled'
  fi

  if [[ "${SKIP_DB_DUMP}" == "true" ]]; then
    l::log 'INFO' 'DB Dump is skipped'
  fi

  if [[ "${DRY_RUN}" == 'true' ]] || [[ "${DEBUG}" == 'true' ]] || [[ "${SKIP_DB_DUMP}" == 'true' ]]; then
    echo ''
  fi
}
alias _log_default_options=l::log_default_options

l::log_and_show_usage_and_exit() {
  local exitCode=${1:-0}
  l::log "${2}" "${3}"
  echo ''
  print::usage
  echo ''
  exit $exitCode
}
alias _log_and_show_usage_and_exit=l::log_and_show_usage_and_exit

l::__stop() {
  local message="${1:-}"

  # shellcheck disable=SC2199
  if [[ "${DEBUG}" == 'false' ]]; then
    l::log 'ERROR' 'l::__stop() is only allowed with --debug option'
    exit 1
  fi

  if [[ -n "${message}" ]]; then
    l::log 'WARN' "STOP:MESSAGE >> ${message}"
  fi

  exit 0
}
alias __stop=l::__stop
