# coding: utf-8
#
# Run the foreman_setup wizard hands-free.
#
# foreman_setup [https://github.com/theforeman/foreman_setup] is a
# Foreman plugin that makes it easier to configure provisioning. This
# script makes it easier to use foreman_setup, which otherwise
# requires the operator to first run foreman-installer, then go
# through a Web wizard where all mistakes are basically fatal, then
# run foreman-installer again.

SubnetParams = Struct.new(
  :interface_name,       # e.g. "eth0"
  :domain_name,          # "cloud.epfl.ch"
  # The other symbol names are in sync with the HTML form fields of Step 2
  :network, :mask, :gateway, :dns_primary, :dns_secondary,
  :from, :to  # DHCP IP range
) do
  # http://stackoverflow.com/questions/5407940
  def initialize *args
    opts = args.last.is_a?(Hash) ? args.pop : Hash.new
    super *args
    opts.each_pair do |k, v|
      self.send "#{k}=", v
    end
  end

  # https://stackoverflow.com/questions/8082423
  def to_h() Hash[each_pair.to_a] end

  def to_params
    ret = to_h
    ret.delete :interface_name
    ret.delete :domain_name
    ret.merge!({
      "name" => _("Provisioning network"),
      "ipam" => "DHCP",
      "boot_mode" => "DHCP"
    })
    return ret
  end
end

FakeRequest = Struct.new(:parameters)

# Re-open the class for a few customizations
class ForemanSetup::ProvisionersController
  attr_accessor :subnet
  
  # Use a mock request object
  def initialize(*args)
    super(*args)
    self.request = FakeRequest.new(:parameters => {})
  end

  # neuter the "all done, transfer to view" plumbing:
  def process_success(ignored)
  end
  def process_error(ignored)
  end
  def redirect_to(ignored)
  end
  def step2_foreman_setup_provisioner_path
  end
  def step3_foreman_setup_provisioner_path
  end
  def step5_foreman_setup_provisioner_path
  end

  # The script of this script
  def run_wizard
    find_myself
    if ! @proxy
      # The SmartProxy object ought to be created through an HTTP/S API
      # call triggered by the Foreman_smartproxy stanza in
      # /usr/share/foreman-installer/modules/foreman/manifests/init.pp
      raise "SmartProxy not found for " + Facter.value(:fqdn)
    end
    if ! @host
      # Creating this is the job of the steps before us in
      # foreman-installer/foreman_provisioning/manifests/init.pp
      raise "Host not found for " + Facter.value(:fqdn)
    end

    step1_auto
    set_params_for_step2_update
    step2_update
    # There is no step 3
    step4
    reload_provisioner
    set_params_for_step4_update
    step4_update
  end

  def step1_auto
    @provisioner = ForemanSetup::Provisioner.new(
      :host_id => @host.id,
      :smart_proxy_id => @proxy.id,
      :provision_interface => @subnet.interface_name)
    @provisioner.save
  end

  def set_params_for_step2_update
    params = self.request.parameters
    params.clear
    provisioner_params = params["foreman_setup_provisioner"] = {
      "subnet_attributes" => @subnet.to_params,
      "domain_name" => @subnet.domain_name,
    }
  end

  # Recover the @provisioner object from the database, sans the updates
  # of #step4.
  #
  # This mimics what would happen in between controller steps in the
  # real, Web-based wizard.
  def reload_provisioner
    if ! @provisioner.id
      @provisioner.save!
    end
    @provisioner = ForemanSetup::Provisioner.find(@provisioner.id)
  end

  def set_params_for_step4_update
    request.parameters.clear
    request.parameters["foreman_setup_provisioner"] = {
      "hostgroup_attributes" => {
        "id" => @provisioner.hostgroup.id,
        "medium_id" => Medium.find_by_name("CentOS mirror").id
      },
      "activation_key" => { "value" => "" },
      "satellite_type" => { "value" => "" },
    }
    request.parameters["medium_type"] = "path"
  end

end

#############################################################

require 'optparse'

subnet = SubnetParams.new

OptionParser.new do |opts|
  opts.banner = "Usage: setup-provisioning.rb [options]"

  opts.on("-e=ENVIRONMENTTYPE",
          "Ignored - This is a rails flag, " +
          "that we parse for compatibility.") do |v| end

  opts.on("--interface-name=IFACE",
          "Interface name for provisioning (e.g. eth0)") do |v|
    subnet.interface_name = v
  end

  opts.on("--domain-name=DOMAIN_NAME",
          "Domain name to set on provisioned hosts (e.g. cloud.epfl.ch)") do |v|
    subnet.domain_name = v
  end

  opts.on("--network-address=DOTTEDQUAD",
          "Adress of network to provision into (e.g. 192.168.10.0)") do |v|
    subnet.network = v
  end

  opts.on("--netmask=DOTTEDQUAD",
          "Netmask of network to provision into (e.g. 255.255.255.0)") do |v|
    subnet.mask = v
  end

  opts.on("--gateway=DOTTEDQUAD",
          "Address of gateway to set on provisioned hosts (e.g. 192.168.10.1)") do |v|
    subnet.gateway = v
  end

  opts.on("--dns-primary=DOTTEDQUAD",
          "Address of primary DNS server") do |v|
    subnet.dns_primary = v
  end

  opts.on("--dns-secondary=DOTTEDQUAD",
          "Address of secondary DNS server (optional)") do |v|
    subnet.dns_secondary = v
  end

  opts.on("--dhcp-range=FROM-TO",
          "Range of addresses to allocate for provisioning") do |v|
    subnet.from, subnet.to = v.split(/[^.0-9]/)
  end    
end.parse!

c = ForemanSetup::ProvisionersController.new
c.subnet = subnet
c.run_wizard

Hostgroup.delete_all
