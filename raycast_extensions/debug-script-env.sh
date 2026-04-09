#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Debug script env
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🤖
# @raycast.packageName Jim Utils

# Documentation:
# @raycast.author jim
# @raycast.authorURL @jafergus

echo "PATH=$PATH"
which node || echo "node not found"
node -v || echo "node won't run"
brew --version || echo "brew not found"
