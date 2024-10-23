#!/usr/bin/env bash

set -euo pipefail

function usage() {
  echo "Usage: ./$(basename "$0") [-h|--help] [-d|--directory] <template(s) directory> --url <Coder URL> --token <Coder session token>"
  echo
  echo "This script pushes example templates a Coder environment."
  echo
  echo "Options:"
  echo " -h, --help                   Show this help text and exit"
  echo " -d, --directory              Directory containing all base templates"
  echo " --url                        URL of coderd server"
  echo " --token                      Coder session"
  exit 1
}

# Allow a failing exit status, as user input can cause this
set +o errexit

LONGOPTS=help,url:,token:,directory:
OPTS=h,d:
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
    --url)
      shift
      CODER_URL="$1"
      ;;
    --token)
      shift
      CODER_SESSION_TOKEN="$1"
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

for TEMPLATE in "${TEMPLATES[@]}"; do
    coder templates push \
        --url $CODER_URL \
        --token $CODER_SESSION_TOKEN \
        --directory $BASE_DIR/$TEMPLATE \
        --yes
done

