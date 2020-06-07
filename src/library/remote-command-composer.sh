#!/usr/bin/env bash

remote_command_composer::compose() {
  local base_command="${1}"
  shift

  local remote_actions=''
  for action in "$@"; do
    remote_actions="${remote_actions}${action};"
  done

  echo "${base_command} '${remote_actions}'"
}

