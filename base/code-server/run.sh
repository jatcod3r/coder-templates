#!/usr/bin/env sh

BOLD='\033[0;1m'

printf "$${BOLD}Installing code-server!\n"

curl -fsSL https://code-server.dev/install.sh | sh
code-server --auth none --port ${local.code_server_port} >/dev/null 2>&1 &
coder login ${data.coder_workspace.me.access_url} --token ${data.coder_workspace_owner.me.session_token}