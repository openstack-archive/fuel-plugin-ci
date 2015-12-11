#!/bin/bash

set -ex

LOGS="${WORKSPACE}/logs/"

rm -rf "${LOGS}"

mkdir -p "${LOGS}"

wget --no-check-certificate "${REPORTED_JOB_URL}/consoleText" -O "${LOGS}/consoleText.txt"
