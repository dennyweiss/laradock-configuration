#!/usr/bin/env bash

print::usage() {
  if [[ -z "${__USAGE_MESSAGE}" ]]; then
    echo "ERROR: Usage message missing"
    exit 1
  fi
  echo -e "${__USAGE_MESSAGE}"
}
alias _usage=print::usage

print::title() {
  echo ''
  echo -e "${1:-Title is missing}"
  echo ''
}
alias _print_title=print::title

print::task() {
  local task_message="${1}"
  local line_prefix="${2:->}"
  echo -e "${line_prefix} ${task_message}"
}
alias _print_task=print::task

print::command() {
  local printable_command="${1}"
  local line_prefix="${2:-  >>>}"
  echo -e "${line_prefix} ${printable_command}"
}
alias _print_command=print::command

