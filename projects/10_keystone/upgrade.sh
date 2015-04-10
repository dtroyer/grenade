#!/usr/bin/env bash

# ``upgrade-keystone``

echo "*********************************************************************"
echo "Begin $0"
echo "*********************************************************************"

# Clean up any resources that may be in use
cleanup() {
    set +o errexit

    echo "*********************************************************************"
    echo "ERROR: Abort $0"
    echo "*********************************************************************"

    # Kill ourselves to signal any calling process
    trap 2; kill -2 $$
}

trap cleanup SIGHUP SIGINT SIGTERM

# Keep track of the grenade directory
RUN_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $GRENADE_DIR/functions

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro

# Source params
source $GRENADE_DIR/grenaderc

# This script exits on an error so that errors don't compound and you see
# only the first error that occurred.
set -o errexit

# Print the commands being run so that we can see the command that triggers
# an error.  It is also useful for following allowing as the install occurs.
set -o xtrace

# Set for DevStack compatibility
TOP_DIR=$TARGET_DEVSTACK_DIR


# Upgrade Keystone
# ================

MYSQL_HOST=${MYSQL_HOST:-localhost}
MYSQL_USER=${MYSQL_USER:-root}
BASE_SQL_CONN=$(source $BASE_DEVSTACK_DIR/stackrc; echo ${BASE_SQL_CONN:-mysql://$MYSQL_USER:$MYSQL_PASSWORD@$MYSQL_HOST})

# Duplicate some setup bits from target DevStack
cd $TARGET_DEVSTACK_DIR
source $TARGET_DEVSTACK_DIR/functions
source $TARGET_DEVSTACK_DIR/stackrc
source $TARGET_DEVSTACK_DIR/lib/stack

SERVICE_HOST=${SERVICE_HOST:-localhost}
SERVICE_PROTOCOL=${SERVICE_PROTOCOL:-http}
S3_SERVICE_PORT=${S3_SERVICE_PORT:-8080}
source $TARGET_DEVSTACK_DIR/lib/database
source $TARGET_DEVSTACK_DIR/lib/apache
source $TARGET_DEVSTACK_DIR/lib/tls

# Get functions from current DevStack
source $TARGET_DEVSTACK_DIR/lib/oslo
source $TARGET_DEVSTACK_DIR/lib/keystone

# Temporary setting until venv change is in DevStack
if [[ -z $KEYSTONE_BIN_DIR ]]; then
    KEYSTONE_BIN_DIR=$(dirname $(which keystone-manage))
fi

# Save current config files for posterity
[[ -d $SAVE_DIR/etc.keystone ]] || cp -pr $KEYSTONE_CONF_DIR $SAVE_DIR/etc.keystone

# install_keystone()
stack_install_service keystone

# calls upgrade-keystone for specific release
upgrade_project keystone $RUN_DIR $BASE_DEVSTACK_BRANCH

# Simulate init_keystone()
# Migrate the database
$KEYSTONE_BIN_DIR/keystone-manage db_sync || die $LINENO "DB sync error"

# Start Keystone
start_keystone

# ensure the service has started
ensure_services_started keystone
ensure_logs_exist key

set +o xtrace
echo "*********************************************************************"
echo "SUCCESS: End $0"
echo "*********************************************************************"
