#!/bin/bash -e

# activate bash xtrace for script
[[ "${DEBUG}" == "true" ]] && set -x || set +x

[ -z $PLUGIN_VERSION ] && exit 1 || echo testplugin version is $PLUGIN_VERSION

export ISO_PATH="${ISO_STORAGE}/${ISO_FILE}"
export ISO_VERSION=$(cut -d'-' -f3-3 <<< $ISO_FILE) 
export FUEL_RELEASE=$(cut -d'-' -f2-2 <<< $ISO_FILE | tr -d '.') 

export ENV_NAME="${ENV_PREFIX}.${ISO_VERSION}"
export VENV_PATH="${HOME}/${FUEL_RELEASE}-venv"

[[ -z ${PLUGIN_PATH} ]] && export PLUGIN_PATH=$(ls ${WORKSPACE}/testplugin*.rpm) \
                                 || echo PLUGIN_PATH=$PLUGIN_PATH

source $VENV_PATH/bin/activate

systest_parameters=''
[[ $USE_SNAPSHOTS == "true"  ]] && systest_parameters+=' -k' || echo new env will be created
[[ $ERASE_AFTER   == "true"  ]] && echo the env will be erased after test || systest_parameters+=' -K'

echo test-group: $TEST_GROUP
echo env-name: $ENV_NAME
echo use-snapshots: $USE_SNAPSHOTS
echo fuel-release: $FUEL_RELEASE
echo venv-path: $VENV_PATH
echo env-name: $ENV_NAME
echo iso-path: $ISO_PATH   
echo plugin-path: $PLUGIN_PATH
echo plugin-checksum: $(md5sum -b $PLUGIN_PATH)

./plugin_test/utils/jenkins/system_tests.sh -t test ${systest_parameters} -i ${ISO_PATH} -j ${JOB_NAME} -o --group=${TEST_GROUP}
