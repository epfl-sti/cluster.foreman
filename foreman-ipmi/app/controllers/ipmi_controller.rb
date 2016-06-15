class IpmiController < ApplicationController
  def index
    subnet_id = Subnet.where(:network=> "192.168.11.0").first.id
    @ipmis = Nic::BMC.all.map {|nic| main_nic = Nic::Managed.where(:host_id => nic.host_id, :subnet_id => subnet_id).first; {ipmi_ip: nic.ip, name: nic.host.name, main_ip: (main_nic ? main_nic.ip : nil)}}.sort_by {|ipmi| ipmi[:name]}
  end
end
