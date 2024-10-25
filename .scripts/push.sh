#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

function usage() {
  echo "Usage: ./$(basename "$0") [-h|--help] [-d|--directory] <template(s) directory> --targets <URL:token>"
  echo
  echo "This script pushes example templates a Coder environment."
  echo
  echo "Options:"
  echo " -h, --help                   Show this help text and exit"
  echo " -d, --directory              Directory containing all base templates"
  echo " -t, --targets                Coder URL Server w/ embedded token (e.g. coder.com:token123)"
  exit 1
}

# Allow a failing exit status
set +o errexit

LONGOPTS=help,targets:,directory:
OPTS=h,d:,t:
PARSED=$(getopt \
          --name="$(basename "$0")" \
          --longoptions=$LONGOPTS \
          --options=$OPTS \
          -- "$@") || usage

set -o errexit

eval set -- "$PARSED"
while true; do
  case "$1" in
    -d|--directory)
      shift
      BASE_DIR="$1"
      ;;
    -t|--targets)
      # The input to --targets should be a multiline string (e.g. newline delimited string)
      shift
      read -rd '' -a CODER_TARGETS <<< "$1" || true
      ;;
    -h|--help)
      usage
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

source "./templates.sh"

# CODER_TARGETS should be an array where each line follows a <URL>:<Token> format.
IFS=";" 
for TARGET in "${CODER_TARGETS[@]}"; do
  read -r CODER_URL CODER_SESSION_TOKEN <<< "$TARGET"
  for TEMPLATE in "${TEMPLATES[@]}"; do
      coder templates push \
          --url $CODER_URL \
          --token $CODER_SESSION_TOKEN \
          --directory $BASE_DIR/$TEMPLATE \
          --yes
  done
done
unset IFS