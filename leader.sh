#!/bin/bash
# Shortcut for leaders — delegates to install.sh with role pre-selected.
exec "$(dirname "${BASH_SOURCE[0]}")/install.sh" <<< "leader"
