#    Copyright 2015 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

import os
import time
from fuelweb_test import logger
from fuelweb_test.helpers import checkers
from fuelweb_test.settings import PLUGIN_PATH
from proboscis.asserts import assert_true
import openstack


def prepare_test_plugin(
        obj, slaves=None, pub_all_nodes=False, ceph_value=False):
    """Copy necessary packages to the master node and install them"""

    obj.env.revert_snapshot("ready_with_%d_slaves" % slaves)

    # copy plugin to the master node
    checkers.upload_tarball(
        obj.env.d_env.get_admin_remote(),
        PLUGIN_PATH, '/var')

    # install plugin
    checkers.install_plugin_check_code(
        obj.env.d_env.get_admin_remote(),
        plugin=os.path.basename(PLUGIN_PATH))

    # prepare fuel
    openstack.assign_net_provider(obj, pub_all_nodes, ceph_value)


def activate_plugin(obj):
    """Enable plugin in settings"""
    plugin_name = 'testplugin'
    msg = "Plugin couldn't be enabled. Check plugin version. Test aborted"
    assert_true(
        obj.fuel_web.check_plugin_exists(obj.cluster_id, plugin_name),
        msg)
    logger.debug('we have plugin element')
    option = {'metadata/enabled': True, }
    obj.fuel_web.update_plugin_data(obj.cluster_id, plugin_name, option)
