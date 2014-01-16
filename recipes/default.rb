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

log 'Create registry database with continuous replication'
http_request 'npm_registry' do
  url "#{Pathname.new(_registry['url']).cleanpath().to_s().gsub(':/', '://')}/_replicate"
  action :post
  headers(
    'Content-Type' => 'application/json'
  )
  message(
    :source => "#{Pathname.new(_isaacs['registry']['url']).cleanpath().to_s().gsub(':/', '://')}",
    :target => "registry",
    :continuous => true,
    :create_target => true
  )
end
log "Configured registry database with continuous replication"

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

log "Setting up replication"
case _replication['flavor']
when 'scheduled'
  cron_d 'npm_registry' do
    action :create
    minute _scheduled['minute']
    hour _scheduled['hour']
    weekday _scheduled['weekday']
    day _scheduled['day']
    command %Q{curl -X POST -H "Content-Type:application/json" #{Pathname.new(_registry['url']).cleanpath().to_s().gsub(':/', '://')}/_replicate -d '{"source":"#{Pathname.new(_isaacs['registry']['url']).cleanpath().to_s().gsub(':/', '://')}/", "target":"registry"}'}
  end

  log "Configured scheduled replication"
when 'continuous'
  log 'Setup continuous replication'
  http_request 'npm_registry' do
    url "#{Pathname.new(_registry['url']).cleanpath().to_s().gsub(':/', '://')}/_replicate"
    action :post
    headers(
      'Content-Type' => 'application/json'
    )
    message(
      :source => "#{Pathname.new(_isaacs['registry']['url']).cleanpath().to_s().gsub(':/', '://')}",
      :target => "registry",
      :continuous => true
    )
  end
  log "Configured continuous replication"
when 'onetime'
  log 'Setup onetime replication'
  http_request 'npm_registry' do
    url "#{Pathname.new(_registry['url']).cleanpath().to_s().gsub(':/', '://')}/_replicate"
    action :post
    headers(
      'Content-Type' => 'application/json'
    )
    message(
      :source => "#{Pathname.new(_isaacs['registry']['url']).cleanpath().to_s().gsub(':/', '://')}",
      :target => "registry"
    )
  end
  log "Configured onetime replication"
else
  log "Skipping replication"
end
