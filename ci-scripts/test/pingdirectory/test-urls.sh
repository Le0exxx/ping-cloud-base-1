#!/bin/sh
set -e

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../../common.sh

testUrl ${PINGDIRECTORY_CONSOLE}