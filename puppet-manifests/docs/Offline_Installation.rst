Deployment in isolated environment
==================================

Requirements
------------

#) Already prepared tar.bz2 archive containing Puppet modules with following structure::

    modules
      module1
      module2
      moduleN

Usage
-----
Call ``install_puppet_master.sh`` with PUPPET_MODULES_ARCHIVE set to path to archive::

    PUPPET_MODULES_ARCHIVE="/home/test/archive.tar.bz2" ./install_puppet_master.sh

It's going to install modules from archive and then run regular scripts used for environment deployment.
