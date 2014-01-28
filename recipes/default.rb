#
# Cookbook Name:: npm_registry
# Recipe:: default
#
# Copyright 2013 Cory Roloff
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

_npm_registry = node['npm_registry']
_git = _npm_registry['git']
_couch_db = node['couch_db']
_config = _couch_db['config']
_httpd = _config['httpd']
_couchdb = _config['couchdb']
_daemons = _config['daemons']
_registry = _npm_registry['registry']
_isaacs = _npm_registry['isaacs']
_replication = _npm_registry['replication']
_scheduled = _replication['flavor'] === "scheduled" ? _replication['scheduled'] : nil

package 'curl' do
  action :install
end

execute 'killall beam' do
  command 'killall beam'
  returns [0, 1]
  action :run
end

service 'couchdb' do
  action :restart
end

http_request 'create registry database' do
  url "#{Pathname.new(_registry['url']).cleanpath().to_s().gsub(':/', '://')}/registry"
  action :put
end


git "#{Chef::Config['file_cache_path']}/npmjs.org" do
  repository _git['url']
  reference _git['reference']
  action :sync
end

log "Installing npm packages"

execute 'npm install couchapp -g' do
  command 'npm install couchapp -g'
  cwd "#{Chef::Config['file_cache_path']}/npmjs.org"
  action :run
end

execute 'npm install couchapp' do
  command 'npm install couchapp'
  cwd "#{Chef::Config['file_cache_path']}/npmjs.org"
  action :run
end

execute 'npm install semver' do
  command 'npm install semver'
  cwd "#{Chef::Config['file_cache_path']}/npmjs.org"
  action :run
end

log "Pushing views"
execute 'push.sh' do
  command " ./push.sh"
  cwd "#{Chef::Config['file_cache_path']}/npmjs.org"
  environment({'npm_package_config_couch' => "#{Pathname.new(_registry['localhost_url']).cleanpath().to_s().gsub(':/', '://')}/registry"})
  action :run
end 

execute 'load-views.sh' do
  command "./load-views.sh"
  cwd "#{Chef::Config[:file_cache_path]}/npmjs.org"
  environment({'npm_package_config_couch' => "#{Pathname.new(_registry['localhost_url']).cleanpath().to_s().gsub(':/', '://')}/registry"})
  action :run
end

bash 'COPY _design/app' do
  code <<-EOH
    curl #{"#{Pathname.new(_registry['url']).cleanpath().to_s().gsub(':/', '://')}/registry"}/_design/scratch -X COPY -H destination:'_design/app'
  EOH
end

execute "couchapp push www/app.js #{"#{Pathname.new(_registry['url']).cleanpath().to_s().gsub(':/', '://')}/registry"}" do
  command "couchapp push www/app.js #{"#{Pathname.new(_registry['url']).cleanpath().to_s().gsub(':/', '://')}/registry"}"
  cwd "#{Chef::Config['file_cache_path']}/npmjs.org"
  action :run
end


