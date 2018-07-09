#
# Cookbook Name:: mongodb3
# Recipe:: default
#
# Copyright 2015, Sunggun Yu
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe 'mongodb3::package_repo'

# Install Mongos package
install_package = %w(mongodb-org-shell mongodb-org-mongos mongodb-org-tools)

install_package.each do |pkg|
  package pkg do
    version node['mongodb3']['package']['version']
    action :install
  end
end

# Mongos configuration
# Create the mongodb user if not exist
user node['mongodb3']['user'] do
  action :create
end

# Create the Mongos config file
template node['mongodb3']['mongos']['config_file'] do
  source 'mongodb.conf.erb'
  owner node['mongodb3']['user']
  mode 0644
  variables(
      :config => node['mongodb3']['config']['mongos']
  )
  helpers Mongodb3Helper
end

# Create the log directory
directory File.dirname(node['mongodb3']['config']['mongos']['systemLog']['path']).to_s do
  owner node['mongodb3']['user']
  action :create
  recursive true
end


# Create the mongod.service file
case node['platform']
  when 'ubuntu'
    template '/lib/systemd/system/mongos.service' do
      cookbook node['mongodb3']['mongos']['systemd_template_cookbook']
      source 'mongos.service.erb'
      mode 0644
      only_if { node['platform_version'].to_f >= 15.04 }
    end
end

# Start the mongod service
service 'mongos' do
  case node['platform']
    when 'ubuntu'
      if node['platform_version'].to_f >= 15.04
        provider Chef::Provider::Service::Systemd
      elsif node['platform_version'].to_f >= 14.04
        provider Chef::Provider::Service::Upstart
      end
  end
  supports :start => true, :stop => true, :restart => true, :status => true
  action :enable
  subscribes :restart, "template[#{node['mongodb3']['mongos']['config_file']}]", :delayed
end
