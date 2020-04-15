#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

set -x

function stop_server()
{
  SERVER_PID=$(pgrep -alf java | grep 'run.properties' | awk '{ print $1; }')
  kill "${SERVER_PID}"
  exit 1
}

if test "${OPERATIONAL_MODE}" != "CLUSTERED_CONSOLE"; then
  echo "post-start: skipping post-start on engine"
  exit 0
fi

# Remove the marker file before running post-start initialization.
POST_START_INIT_MARKER_FILE="${OUT_DIR}/instance/post-start-init-complete"
rm -f "${POST_START_INIT_MARKER_FILE}"

# Wait until pingaccess admin localhost is available
pingaccess_admin_wait
  
# ADMIN_CONFIGURATION_COMPLETE is used as a marker file that tracks if server was initially configured.
#
# If ADMIN_CONFIGURATION_COMPLETE does not exist then set initial configuration.
ADMIN_CONFIGURATION_COMPLETE=${OUT_DIR}/instance/ADMIN_CONFIGURATION_COMPLETE
if ! test -f "${ADMIN_CONFIGURATION_COMPLETE}"; then

  sh "${HOOKS_DIR}/81-import-initial-configuration.sh"
  # Stop the server if an error has occured upon importing the intial configuration
  if test ${?} -ne 0; then
    echo "post-start: admin post-start import-initial-configuration script failed"
    stop_server
  fi

  touch ${ADMIN_CONFIGURATION_COMPLETE}

# Since this isn't initial deployment, check and change the password if from disk is different than the desired value
elif ! test "$(readPasswordFromDisk)" = "${PA_ADMIN_USER_PASSWORD}"; then

  changePassword

  # Stop the server if an error has occured changing the password
  if test ${?} -ne 0; then
    echo "post-start: admin post-start change password failed"
    stop_server
  fi
  
fi

# Upload a backup right away after starting the server.
sh "${HOOKS_DIR}/90-upload-backup-s3.sh"
BACKUP_STATUS=${?}

echo "post-start: data backup status: ${BACKUP_STATUS}"

# Write the marker file if post-start succeeds.
if test "${BACKUP_STATUS}" -eq 0; then
  touch "${POST_START_INIT_MARKER_FILE}"
  exit 0
fi

# Kill the container if post-start fails.
echo "post-start: admin post-start backup failed"
stop_server