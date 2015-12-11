#!/bin/bash
# Copyright 2014 OpenStack Foundation.
# Copyright 2014 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

MODULE_PATH=/usr/share/puppet/modules

function remove_module {
  local SHORT_MODULE_NAME=$1
  if [ -n "$SHORT_MODULE_NAME" ]; then
    rm -Rf "$MODULE_PATH/$SHORT_MODULE_NAME"
  else
    echo "ERROR: remove_module requires a SHORT_MODULE_NAME."
  fi
}

# Array of modules to be installed key:value is module:version.
declare -A MODULES

# Array of modues to be installed from source and without dependency resolution.
# key:value is source location, revision to checkout
declare -A SOURCE_MODULES

#NOTE: if we previously installed kickstandproject-ntp we nuke it here
# since puppetlabs-ntp and kickstandproject-ntp install to the same dir
if grep kickstandproject-ntp /etc/puppet/modules/ntp/Modulefile &> /dev/null; then
  remove_module "ntp"
fi


# freenode #puppet 2012-09-25:
# 18:25 < jeblair> i would like to use some code that someone wrote,
# but it's important that i understand how the author wants me to use
# it...
# 18:25 < jeblair> in the case of the vcsrepo module, there is
# ambiguity, and so we are trying to determine what the author(s)
# intent is
# 18:30 < jamesturnbull> jeblair: since we - being PL - are the author
# - our intent was not to limit it's use and it should be Apache
# licensed

MODULES["puppetlabs-vcsrepo"]="1.2.0"
MODULES["puppetlabs-apt"]="1.6.0"
MODULES["puppetlabs-firewall"]="1.1.3"
MODULES["puppetlabs-concat"]="1.1.0"
MODULES["puppetlabs-mysql"]="2.3.1"
MODULES["puppetlabs-ntp"]="3.1.2"
MODULES["puppetlabs-postgresql"]="3.4.2"
MODULES["puppetlabs-rsync"]="0.3.1"
MODULES["puppetlabs-stdlib"]="4.5.1"
MODULES["puppetlabs-java_ks"]="1.2.6"
MODULES["puppetlabs-nodejs"]="0.7.1"
MODULES["puppetlabs-apache"]="1.4.1"
MODULES["maestrodev-rvm"]="1.11.0"
MODULES["thias-sysctl"]="1.0.0"
MODULES["thias-php"]="1.1.0"
MODULES["darin-zypprepo"]="1.0.1"
MODULES["elasticsearch/elasticsearch"]="0.4.0"
MODULES["ripienaar-module_data"]="0.0.3"
MODULES["rodjek-logrotate"]="1.1.1"
MODULES["saz-sudo"]="3.0.9"
MODULES["golja-gnupg"]="1.2.1"
MODULES["gnubilafrance-atop"]="0.0.4"

SOURCE_MODULES["https://github.com/iberezovskiy/puppet-mongodb"]="0.1"
SOURCE_MODULES["https://github.com/monester/puppet-bacula"]="v0.4.0.1"
SOURCE_MODULES["https://github.com/monester/puppet-libvirt"]="0.3.2-3"
SOURCE_MODULES["https://github.com/SergK/puppet-display"]="0.5.0"
SOURCE_MODULES["https://github.com/SergK/puppet-glusterfs"]="0.0.4"
SOURCE_MODULES["https://github.com/SergK/puppet-sshuserconfig"]="0.0.1"
SOURCE_MODULES["https://github.com/SergK/puppet-znc"]="0.0.9"
SOURCE_MODULES["https://github.com/teran/puppet-bind"]="0.5.1-hiera-debian-keys-controls-support"
SOURCE_MODULES["https://github.com/teran/puppet-mailman"]="0.1.4+user-fix"
SOURCE_MODULES["https://github.com/teran/puppet-nginx"]="0.1.1+ssl_ciphers(renew)"

MODULE_LIST=`puppet module list`

# Install all the modules
for MOD in ${!MODULES[*]} ; do
  # If the module at the current version does not exist upgrade or install it.
  if ! echo $MODULE_LIST | grep "$MOD ([^v]*v${MODULES[$MOD]}" >/dev/null 2>&1
  then
    # Attempt module upgrade. If that fails try installing the module.
    if ! puppet module upgrade $MOD --version ${MODULES[$MOD]} >/dev/null 2>&1
    then
      # This will get run in cron, so silence non-error output
      echo "Installing ${MOD} ..."
      puppet module install --target-dir $MODULE_PATH $MOD --version ${MODULES[$MOD]} >/dev/null
    fi
  fi
done

MODULE_LIST=`puppet module list`

# Make a second pass, just installing modules from source
for MOD in ${!SOURCE_MODULES[*]} ; do
  # get the name of the module directory
  if [ `echo $MOD | awk -F. '{print $NF}'` = 'git' ]; then
    echo "Remote repos of the form repo.git are not supported: ${MOD}"
    exit 1
  fi
  MODULE_NAME=`echo $MOD | awk -F- '{print $NF}'`
  # set up git base command to use the correct path
  GIT_CMD_BASE="git --git-dir=${MODULE_PATH}/${MODULE_NAME}/.git --work-tree ${MODULE_PATH}/${MODULE_NAME}"
  # treat any occurrence of the module as a match
  if ! echo $MODULE_LIST | grep "${MODULE_NAME}" >/dev/null 2>&1; then
    # clone modules that are not installed
    git clone $MOD "${MODULE_PATH}/${MODULE_NAME}"
  else
    if [ ! -d ${MODULE_PATH}/${MODULE_NAME}/.git ]; then
      echo "Found directory ${MODULE_PATH}/${MODULE_NAME} that is not a git repo, deleting it and reinstalling from source"
      remove_module $MODULE_NAME
      echo "Cloning ${MODULE_PATH}/${MODULE_NAME} ..."
      git clone $MOD "${MODULE_PATH}/${MODULE_NAME}"
    elif [ `${GIT_CMD_BASE} remote show origin | grep 'Fetch URL' | awk -F'URL: ' '{print $2}'` != $MOD ]; then
      echo "Found remote in ${MODULE_PATH}/${MODULE_NAME} that does not match desired remote ${MOD}, deleting dir and re-cloning"
      remove_module $MODULE_NAME
      git clone $MOD "${MODULE_PATH}/${MODULE_NAME}"
    fi
  fi
  # fetch the latest refs from the repo
  $GIT_CMD_BASE fetch
  # make sure the correct revision is installed, I have to use rev-list b/c rev-parse does not work with tags
  if [ `${GIT_CMD_BASE} rev-list HEAD --max-count=1` != `${GIT_CMD_BASE} rev-list ${SOURCE_MODULES[$MOD]} --max-count=1` ]; then
    # checkout correct revision
    $GIT_CMD_BASE checkout ${SOURCE_MODULES[$MOD]}
  fi
done
