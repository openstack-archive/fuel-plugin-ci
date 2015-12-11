#!/usr/bin/python

import sys, getopt
import os.path
import netaddr
import re
import paramiko
import time
from hashlib import sha512
from xmlbuilder import XMLBuilder

IPMI_USERNAME = os.getenv('IPMI_USERNAME', '')
IPMI_PASSWORD = os.getenv('IPMI_PASSWORD', '')

CISCO_USERNAME = os.getenv('CISCO_USERNAME', '')
CISCO_PASSWORD = os.getenv('CISCO_PASSWORD', '')

servers = {
  'cz5547' : { 'hostname' : 'cz5547-kvm.host-telecom.com', 'mac' : 'a0-d3-c1-ef-2c-d8', 'int1' : 'gi 0/1',  'int2' : 'gi 0/2'  },
  'cz5548' : { 'hostname' : 'cz5548-kvm.host-telecom.com', 'mac' : 'a0-d3-c1-ef-16-ec', 'int1' : 'gi 0/3',  'int2' : 'gi 0/4'  },
  'cz5549' : { 'hostname' : 'cz5549-kvm.host-telecom.com', 'mac' : 'a0-d3-c1-ef-32-cc', 'int1' : 'gi 0/5',  'int2' : 'gi 0/6'  },
  'cz5550' : { 'hostname' : 'cz5550-kvm.host-telecom.com', 'mac' : 'a0-2b-b8-1f-48-4c', 'int1' : 'gi 0/7',  'int2' : 'gi 0/8'  },
  'cz5551' : { 'hostname' : 'cz5551-kvm.host-telecom.com', 'mac' : 'a0-2b-b8-1f-48-fc', 'int1' : 'gi 0/9',  'int2' : 'gi 0/10' },
  'cz5552' : { 'hostname' : 'cz5552-kvm.host-telecom.com', 'mac' : 'a0-2b-b8-1f-4a-88', 'int1' : 'gi 0/11', 'int2' : 'gi 0/12' },
  'cz5553' : { 'hostname' : 'cz5553-kvm.host-telecom.com', 'mac' : 'a0-2b-b8-1f-4a-ac', 'int1' : 'gi 0/19', 'int2' : 'gi 0/20' },
  'cz5554' : { 'hostname' : 'cz5554-kvm.host-telecom.com', 'mac' : 'a0-2b-b8-1f-4a-90', 'int1' : 'gi 0/21', 'int2' : 'gi 0/22' },
  'cz5555' : { 'hostname' : 'cz5555-kvm.host-telecom.com', 'mac' : 'a0-2b-b8-1f-4c-9c', 'int1' : 'gi 0/23', 'int2' : 'gi 0/24' },
  'cz5556' : { 'hostname' : 'cz5556-kvm.host-telecom.com', 'mac' : 'a0-2b-b8-1f-4c-48', 'int1' : 'gi 0/31', 'int2' : 'gi 0/32' },
  'cz5557' : { 'hostname' : 'cz5557-kvm.host-telecom.com', 'mac' : 'a0-2b-b8-1f-4a-08', 'int1' : 'gi 0/33', 'int2' : 'gi 0/34' },
  'cz5558' : { 'hostname' : 'cz5558-kvm.host-telecom.com', 'mac' : 'a0-2b-b8-1f-4c-74', 'int1' : 'gi 0/35', 'int2' : 'gi 0/36' },
  'cz5559' : { 'hostname' : 'cz5559-kvm.host-telecom.com', 'mac' : 'a0-2b-b8-1f-4c-54', 'int1' : 'gi 0/13', 'int2' : 'gi 0/14' },
  'cz5560' : { 'hostname' : 'cz5560-kvm.host-telecom.com', 'mac' : '00-00-00-00-00-00', 'int1' : 'gi 0/15', 'int2' : 'gi 0/16' },
  'cz5561' : { 'hostname' : 'cz5561-kvm.host-telecom.com', 'mac' : 'a0-2b-b8-1f-4b-ec', 'int1' : 'gi 0/17', 'int2' : 'gi 0/18' },
  'cz5562' : { 'hostname' : 'cz5562-kvm.host-telecom.com', 'mac' : '00-00-00-00-00-00', 'int1' : 'gi 0/25', 'int2' : 'gi 0/26' },
  'cz5563' : { 'hostname' : 'cz5563-kvm.host-telecom.com', 'mac' : '00-00-00-00-00-00', 'int1' : 'gi 0/27', 'int2' : 'gi 0/28' },
  'cz5564' : { 'hostname' : 'cz5564-kvm.host-telecom.com', 'mac' : '00-00-00-00-00-00', 'int1' : 'gi 0/29', 'int2' : 'gi 0/30' },
}

vlans = {
  '221' : { 'network' : netaddr.IPNetwork('172.16.39.0/26') },
  '222' : { 'network' : netaddr.IPNetwork('172.16.39.64/26') },
  '223' : { 'network' : netaddr.IPNetwork('172.16.39.128/26') },
  '224' : { 'network' : netaddr.IPNetwork('172.16.39.192/26') },
  '225' : { 'network' : netaddr.IPNetwork('172.16.37.128/26') },
  '226' : { 'network' : netaddr.IPNetwork('172.16.37.192/26') },
}

switches = {
  'cz-sw' : { 'hostname' : '193.161.84.243 ' },
}

class fuelLab:
  """ Lab definition """
  def __init__(self):
    self.name="Lab1"
    self.fuel = None
    self.iso = None
    self.vlan = None
    self.public_vlan = None
    self.vlan_range = None
    self.nodes = []
    self.tftp_root = "/var/lib/tftpboot"

  def set_host(self,host):
    if host in servers.keys():
      self.name = host
      self.fuel = servers[host]
    else:
      print "Node "+node+" not defined"
      sys.exit(1)

  def add_node(self,node):
    if re.match('^[1-9a-f]{2}:[1-9a-f]{2}$',node):
      node = re.sub(':','-',node)
      for name in servers.keys():
        if re.search(node+'$', servers[name]['mac']):
          self.add_node(name)
          return
    if node in servers.keys():
      self.nodes.append(servers[node])
    else:
      print "Node "+node+" not defined"
      sys.exit(1)

  def set_vlan(self,vlan):
    if vlan in vlans.keys():
      self.vlan = vlan
    else:
      print "Vlan "+vlan+" not defined"
      sys.exit(1)

  def set_public_vlan(self,vlan):
    if vlan in vlans.keys():
      self.public_vlan = vlan
    else:
      print "Vlan "+vlan+" not defined"
      sys.exit(1)

  def set_vlan_range(self,vlan_range):
    res = re.match(r"(\d+)\-(\d+)",vlan_range)
    if res:
      min,max = int(res.group(1)),int(res.group(2))
      if(max-min > 1 and max-min < 20):
        self.vlan_range = str(min)+'-'+str(max)
      else:
        print "Range is too big"
    else:
      print "Wrong range"

  def create_pxe(self):
    self.pxe_file = "/var/lib/tftpboot/pxelinux.cfg/01-"+self.fuel['mac']
    f = open(self.pxe_file, "w")
    ip = vlans[self.vlan]['network']
    nfs_share = "nfs:" +str(ip.ip+1) + ":" + self.tftp_root + self.fuel_path
    host_ip = ip.ip + 2
    host_gw = ip.ip + ip.size - 2
    host_netmask = ip.netmask
    f.write("DEFAULT fuel\nPROMPT 0\nTIMEOUT 0\nTOTALTIMEOUT 0\nONTIMEOUT fuel\n\n")
    f.write("LABEL fuel\nKERNEL %s/isolinux/vmlinuz\nINITRD %s/isolinux/initrd.img\n" % (self.fuel_path, self.fuel_path))
    f.write("APPEND biosdevname=0 ks=%s repo=%s ip=%s netmask=%s gw=%s hostname=fuel-lab-%s.mirantis.com showmenu=no installdrive=sda ksdevice=eth0 forceformat=yes\n" % \
      ( nfs_share + "/ks.cfg", nfs_share ,host_ip, host_netmask, host_gw, self.name ) )
    f.close()

  def mac_in_nodes(self,mac):
    for node in self.nodes:
      if node['mac'] == mac:
        return True
    return False

  def update_dhcpd(self):
    mac = re.sub('-',':',self.fuel['mac'])
    fuel = self.fuel
    ip = vlans[self.vlan]['network']
    filename = "/tmp/deploy." + str(os.getpid())
    x = XMLBuilder('network')
    x.name("lab" + str(self.vlan))
    x.bridge(name = "br"+self.vlan, stp="off", delay="0")
    with x.forward(mode = "route", dev="eth0"):
      x.interface(dev="eth0")
    with x.ip(address = str(ip.ip+1), netmask="255.255.255.192"):
      with x.dhcp:
        x.host(mac=mac, ip=str(ip.ip+2))
        x.bootp(file="pxelinux.0")
      x.tftp(root="/var/lib/tftpboot")
    print str(x)+"\n"
    f=open(filename,"w")
    f.write(str(x)+"\n")
    f.close()
    os.system("sudo ifconfig br%s down" % self.vlan)
    os.system("virsh net-destroy lab%s" % self.vlan)
    os.system("virsh net-create %s" % filename)
    os.system("sudo brctl addif br%s eth1.%s" % (self.vlan, self.vlan))

  def switch_write(self):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(
        paramiko.AutoAddPolicy())
    ssh.connect('193.161.84.243', username=CISCO_USERNAME, password=CISCO_PASSWORD)
    sess = ssh.invoke_shell()
    vlans = "%s,%s" % (self.vlan, self.vlan_range)
    print sess.recv(5000)
    sess.send("conf t\n")
    time.sleep(1)
    for node in self.nodes + [self.fuel]:
      print sess.recv(5000)
      sess.send( "interface %s\nswitchport trunk native vlan %s\nswitchport trunk allowed vlan %s\n" % (node['int1'], self.vlan, vlans) )
      sess.send( "interface %s\nno switchport trunk native vlan\n" % ( node['int2'] ) )
      if self.public_vlan:
        sess.send( "switchport trunk native vlan %s\nswitchport trunk allowed vlan %s\n" % (self.public_vlan, vlans+","+self.public_vlan) )
      else:
        sess.send( "switchport trunk allowed vlan %s\n" % (vlans) )
      time.sleep(1)
    time.sleep(2)
    sess.send("end\nexit\n")
    print sess.recv(5000)

  def reboot_master(self):
    print "Rebooting Fuel Master: %s" % self.fuel['hostname']
    os.system("ipmitool -I lanplus -L operator -H " + self.fuel['hostname'] + " -U " + IPMI_USERNAME + " -P '" + IPMI_PASSWORD + "' power cycle")

  def reboot_nodes(self):
    for node in self.nodes:
      print "Reboot node: %s" % node['hostname']
      os.system("ipmitool -I lanplus -L operator -H " + node['hostname'] + " -U " + IPMI_USERNAME + " -P '" + IPMI_PASSWORD + "' power cycle")

  def set_iso(self,iso):
    iso = os.path.abspath(iso)
    if os.path.isfile(iso):
      self.iso = iso
      self.fuel_path = "/" + sha512(iso).hexdigest()[:16]
    else:
      print "ISO: %s not found" % iso
      sys.exit(1)

  def unpack_iso(self):
    mount_iso_path = self.tftp_root + self.fuel_path
    if os.path.ismount(mount_iso_path):
      return
    if not os.path.exists(mount_iso_path):
      os.system("mkdir " + mount_iso_path)
    os.system("sudo mount -o loop,ro %s %s" % ( self.iso, mount_iso_path) )

  def check_params(self, mode):
    if not mode:
      return False
    if 'install_fuel' in mode and not ( self.fuel and self.iso and self.vlan) :
      return False
    if 'reboot'       in mode and not ( self.nodes ) :
      return False
    if 'configure'    in mode and not ( self.fuel and self.vlan and self.vlan_range and self.nodes ) :
      return False
    return True



def usage():
  print '''
  == For existing configuration you must specify:
\nEXAMPLE:\tdeploy.py --host=cz5551 --vlan=221 --iso=/srv/downloads/fuel.iso\n
  --host          Host to use as master node
  --vlan          Preconfigured lab admin vlan
  --iso           ISO to install
\n == To reboot nodes you need only: ==
\nEXAMPLE:\tdeploy.py (--reboot-nodes|-r) --node cz5547 --node 2c:d8 ...\n
  --reboot-nodes  Reboot only nodes
  --node=cz0000   Node to reboot
\n == For NEW configuration (DevOps team only) ==
\nEXAMPLE:\tdeploy.py --host cz5551 --vlan 221 [--public-vlan=222] --vlan-range 300-305 [--iso fuel.iso] --node cz5547 --node cz5548 --node cz5549\n
  --public-vlan 222  Set untagged eth1 vlan (if needed)
  --vlan-range 51-55 Vlans for storage/private/management/etc
  --node             Node to include in lab'''

def main(argv):
  lab = fuelLab()
  mode = []
  nodes = []
  try:
     opts, args = getopt.getopt(argv,"hr",["host=","vlan=","public-vlan=","vlan-range=","iso=","node=","help","reboot-nodes"])
  except getopt.GetoptError:
     usage()
     sys.exit(2)
  for opt, arg in opts:
    if opt in ( "-h", "--help" ):
      usage()
      sys.exit(0)
    elif opt == "--host":
      lab.set_host(arg)
    elif opt == "--vlan":
      lab.set_vlan(arg)
    elif opt == "--public-vlan":
      mode.append('configure')
      lab.set_public_vlan(arg)
    elif opt == "--vlan-range":
      mode.append('configure')
      lab.set_vlan_range(arg)
    elif opt == "--iso":
      mode.append('install_fuel')
      lab.set_iso(arg)
    elif opt == "--node":
      lab.add_node(arg)
      nodes.append(arg)
    elif opt in ( "--reboot-nodes", "-r" ):
      mode.append('reboot')

  if not lab.check_params(mode):
    usage()
    exit(1)

  if 'reboot' in mode:
    lab.reboot_nodes()
    return
  if 'configure' in mode:
    lab.switch_write()
    lab.update_dhcpd()
    vlan = vlans[lab.vlan]['network']
    if lab.public_vlan:
      vlan_p = vlans[lab.public_vlan]['network']
      pub_net = vlan_p
      pub_gw  = vlan_p[-2]
    else:
      pub_net = pub_gw = "Not available"
    print '''
================================================================================
Lab configured:

Fuel host ip: %s
Admin network:  ( Untagged eth0 )
  network: %s
  gateway: %s
Public network: ( Untagged eth1 )
  network: %s
  gateway: %s
Vlans available: %s

To install Fuel:
  deploy.py --host %s --vlan %s --iso /srv/downloads/fuel.iso

To reboot all nodes:
  deploy.py -r --node %s
================================================================================
    ''' % ( vlan[2], vlan, vlan[-2], pub_net, pub_gw, lab.vlan_range, lab.name, lab.vlan, " --node ".join(nodes) )

  if 'install_fuel' in mode:
        lab.update_dhcpd()
        lab.create_pxe()
        lab.unpack_iso()
        lab.reboot_master()
        os.system("echo 'rm %s' | at now + 10 minutes" % lab.pxe_file)

if __name__ == "__main__":
  main(sys.argv[1:])
