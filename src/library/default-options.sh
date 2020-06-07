#!/usr/bin/env bash

options::init_default() {
  DEBUG="false"
  DRY_RUN="false"
  SHOW_HELP='false'

  # shellcheck disable=SC2199
  if [[ "${@}" == *'--debug'* ]]; then
    DEBUG="true"
  fi

  # shellcheck disable=SC2199
  if [[ "${@}" == *'--dry-run'* ]]; then
    DRY_RUN="true"
  fi

  # shellcheck disable=SC2199
  if [[ "${@}" == *'--help'* ]]; then
    SHOW_HELP='true'
  fi
}

options::init_default "$ARGS"
