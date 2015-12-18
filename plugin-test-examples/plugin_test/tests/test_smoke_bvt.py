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
import os.path
from proboscis import test
from fuelweb_test.helpers.decorators import log_snapshot_after_test
from fuelweb_test import logger
from fuelweb_test.tests.base_test_case import SetupEnvironment
from fuelweb_test.tests.base_test_case import TestBasic
from helpers import plugin
from helpers import openstack


@test(groups=["plugins"])
class TestPlugin(TestBasic):

    ostf_msg = 'OSTF tests passed successfully.'

    cluster_id = ''

    @test(depends_on=[SetupEnvironment.prepare_slaves_2],
          groups=["install_testplugin"])
    @log_snapshot_after_test
    def install_testplugin(self):
        """Install Plugin and create cluster

        Scenario:
            1. Revert snapshot "ready_with_3_slaves"
            2. Upload plugin to the master node
            3. Install plugin and additional packages
            4. Enable Neutron with tunneling segmentation
            5. Create cluster

        Duration 20 min

        """

        plugin.prepare_test_plugin(self, slaves=2)

    @test(depends_on=[SetupEnvironment.prepare_slaves_2],
          groups=["plugin_smoke"])
    @log_snapshot_after_test

    def plugin_smoke(self):
        """Deploy a cluster with Plugin

        Scenario:
            1. Revert snapshot "ready_with_2_slaves"
            2. Create cluster
            3. Add a node with controller role
            4. Add a node with compute role
            6. Enable Contrail plugin
            5. Deploy cluster with plugin

        Duration 90 min

        """
        plugin.prepare_test_plugin(self, slaves=2)

        # enable plugin in settings
        plugin.activate_plugin(self)

        self.fuel_web.update_nodes(
            self.cluster_id,
            {
                'slave-01': ['controller'],
                'slave-02': ['compute'],
            })

        # deploy cluster
        openstack.deploy_cluster(self)

        self.fuel_web.run_ostf(
            cluster_id=self.cluster_id,
            should_fail=2,
            failed_test_name=[('Check network connectivity from instance via floating IP'),('Launch instance with file injection')]
        )
