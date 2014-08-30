require "capistrano/node-deploy"

set :stages, %w(production staging)
set :default_stage, "staging"
require 'capistrano/ext/multistage'

set :application, "pokebattle-sim"
set :repository,  "git@github.com:sarenji/pokebattle-sim.git"

set :scm, :git
set :user, "combee"
set :use_sudo, false
set :ssh_options, { :forward_agent => true }

set :branch, fetch(:branch, "master")

set :node_user, "combee"
set :deploy_to, "/home/combee/apps/pokebattle-sim"
set :app_environment, "`cat #{shared_path}/env.txt`"
set :node_binary, "/usr/local/bin/node"
set :app_command, "start.js"

# Use own upstart file config
set(:upstart_file_contents) {
<<EOD
#!upstart
description "#{application} node app"
author      "capistrano"

start on runlevel [2345]
stop on shutdown

respawn
respawn limit 99 5
kill timeout #{kill_timeout}

script
    sudo sh -c "ulimit -n 32768 && exec su #{node_user}"
    cd #{current_path} && exec sudo -u #{node_user} NODE_ENV=#{node_env} #{app_environment} #{node_binary} #{current_path}/#{app_command} 2>> #{stderr_log_path} 1>> #{stdout_log_path}
end script
EOD
}

# Necessary to calculate MD5 hash of assets
namespace :sim do
  desc "sets up necessary files"
  task :setup do
    warn 'Copy aws_config.json and nodetime.json to the server\'s shared'
    warn 'folder. An example file is located at aws_config.json.example and'
    warn 'nodetime.json.example'
  end

  desc "symlinks all necessary files"
  task :symlink do
    run "ln -fs #{shared_path}/aws_config.json #{release_path}/aws_config.json"
    run "ln -fs #{shared_path}/nodetime.json #{release_path}/nodetime.json"
  end

  desc "compiles and deploys all assets"
  task :deploy_assets do
    run "cd #{release_path} && ./node_modules/grunt-cli/bin/grunt deploy:assets"
  end

  desc "migrates the database"
  task :migrate do
    run "cd #{release_path} && NODE_ENV=#{fetch(:node_env)} ./node_modules/knex/lib/bin/cli.js migrate:latest"
  end
end

after "deploy:setup", "sim:setup"
after "node:install_packages", "sim:symlink"
after "node:install_packages", "sim:deploy_assets"
after "node:install_packages", "sim:migrate"

# clean up old releases on each deploy
after "deploy", "deploy:cleanup"
