#!/bin/sh

. "./utils.lib.sh"

beluga_log "Copying SSH configuration files"
test -f /known_hosts && cp /known_hosts /.ssh
test -f /id_rsa && cp /id_rsa /.ssh

beluga_log "Copying kubectl to the data directory"
which kubectl | xargs -I {} cp {} /data

beluga_log "Checking kubectl executable in data directory"
if test ! -f /data/kubectl; then
    beluga_log "Failed to locate /data/kubectl" "ERROR"
    exit 1
fi

beluga_log "Downloading skbn from ping-artifacts bucket"
wget -qO /data/skbn https://ping-artifacts.s3-us-west-2.amazonaws.com/pingcommon/skbn/0.5.0/skbn

beluga_log "Checking skbn executable in data directory"
if test ! -f /data/skbn; then
    beluga_log "Failed to locate /data/skbn" "ERROR"
    exit 1
fi

beluga_log "Updating skbn permission"
chmod +x /data/skbn

beluga_log "Generate a dummy topology JSON file so the hook that generates it in the image is not triggered"

TOPOLOGY_FILE=/data/topology.json
cat <<EOF > "${TOPOLOGY_FILE}"
{
        "serverInstances" : []
}
EOF

beluga_log "Execution completed successfully"

exit 0