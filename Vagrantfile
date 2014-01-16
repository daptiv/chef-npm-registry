# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure('2') do |config|
  config.vm.box = 'opscode-ubuntu-12.04-chef11'
  config.vm.box_url = 'https://opscode-vm.s3.amazonaws.com/vagrant/opscode_ubuntu-12.04_chef-11.2.0.box'

  config.vm.network :forwarded_port, guest: 5984, host: 5984
  config.berkshelf.enabled = true

  config.vm.provision :chef_solo do |chef|
    chef.json = {
      'couch_db' => {
        'config' => {
          'couchdb' => {
            'src_version' => '1.5.0'
          },
          'httpd' => {
            'bind_address' => '0.0.0.0',
            'secure_rewrites' => false
          }
        }
      },
      'npm_registry' => {
        'replication' => {
          'flavor' => 'onetime'
        }
      }
    }
    chef.run_list = [
      'recipe[apt]',
      'recipe[build-essential]',
      'recipe[couchdb::source]',
      'recipe[git]',
      'recipe[nodejs::install_from_binary]',
      'recipe[npm_registry]'
    ]
  end
end