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

set :node_user, "combee"
set :deploy_to, "/home/combee/apps/pokebattle-sim"
set :app_environment, "`cat #{shared_path}/env.txt`"
set :node_binary, "/home/combee/.nvm/v0.10.23/bin/node"
set :app_command, "start.js"

role :web, "sim.pokebattle.com"
role :app, "sim.pokebattle.com"

# Necessary to calculate MD5 hash of assets
namespace :sim do
  desc "compiles all assets"
  task :compile do
    run "cd #{release_path} && grunt concurrent:compile"
  end
end

after "node:install_packages", "sim:compile"

# clean up old releases on each deploy
after "deploy", "deploy:cleanup"
