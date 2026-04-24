#!/bin/bash
set -eu

cmd="${1:-neo4j}"

# Keep startup behavior simple and robust for the Ubuntu variant.
# - If command is "neo4j", force foreground console mode.
# - If running as root, drop privileges to neo4j.
if [ "${cmd}" = "neo4j" ]; then
    if [ "$(id -u)" = "0" ]; then
        exec su-exec neo4j:neo4j neo4j console
    else
        exec neo4j console
    fi
fi

if [ "$(id -u)" = "0" ]; then
    exec su-exec neo4j:neo4j "$@"
else
    exec "$@"
fi
