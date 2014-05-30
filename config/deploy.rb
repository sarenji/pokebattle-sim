require "capistrano/node-deploy"

set :application, "pokebattle-sim"
set :repository,  "git@github.com:sarenji/pokebattle-sim.git"

set :scm, :git
set :user, "combee"
set :use_sudo, false
set :ssh_options, { :forward_agent => true }
set :default_environment, {
  # TODO: Is there a nicer way of including `nvm`?
  'PATH' => "$HOME/.nvm/v0.10.23/bin:$PATH"
}

set :branch, fetch(:branch, "master")

set :node_user, "combee"
set :deploy_to, "/home/combee/apps/pokebattle-sim"
set :app_environment, "`cat #{shared_path}/env.txt`"
set :node_binary, "/home/combee/.nvm/v0.10.23/bin/node"
set :app_command, "start.js"

role :web, "sim.pokebattle.com"
role :app, "sim.pokebattle.com"

# Necessary to calculate MD5 hash of assets
namespace :sim do
  desc "sets up necessary files"
  task :setup do
    warn 'Copy aws_config.json and newrelic.js to the server\'s shared folder.'
    warn 'An example file is located at aws_config.json.example and'
    warn 'newrelic.js.example'
  end

  desc "symlinks all necessary files"
  task :symlink do
    run "ln -fs #{shared_path}/aws_config.json #{release_path}/aws_config.json"
    run "ln -fs #{shared_path}/newrelic.js #{release_path}/newrelic.js"
  end

  desc "compiles and deploys all assets"
  task :deploy_assets do
    run "cd #{release_path} && ./node_modules/grunt-cli/bin/grunt deploy:assets"
  end

  desc "migrates the database"
  task :migrate do
    run "cd #{release_path} && ./node_modules/grunt-cli/bin/grunt knexmigrate:latest"
  end
end

after "deploy:setup", "sim:setup"
after "node:install_packages", "sim:symlink"
after "node:install_packages", "sim:deploy_assets"
after "node:install_packages", "sim:migrate"

# clean up old releases on each deploy
after "deploy", "deploy:cleanup"
