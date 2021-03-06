# require "bundler/capistrano"            # install all the new missing plugins...
# require "capistrano/ext/multistage"     # deploy on all the servers..
# # require "delayed/recipes"               # load this for delayed job..
# require "rvm/capistrano"                # if you are using rvm on your server..
# require "bundler/setup"
require "bundler/capistrano"
require "rvm/capistrano"

server "54.255.153.68", :app, :web, :db, :primary => true #ip of the server
# set :stages, %w{testing production}
# set :default_stage, "production"
set :application, "manndi"

set :repository,  "git@bitbucket.org:vedanta/manndi.git"
set :branch, `git rev-parse --abbrev-ref HEAD` # use current branch
set :scm, :git # You can set :scm explicitly or Capistrano will make an intelligent guess based on known version control directory names
# set :migrate_target,  :current
# set :ssh_options,     { :forward_agent => true }
# set :normalize_asset_timestamps, false
set :rails_env, "production"

# set :rvm_ruby_string, '2.1.0'             # ruby version you are using...

set :user, "ubuntu"

set :port, 22
set :deploy_to, "/home/#{user}/apps/#{application}"
set :deploy_via, :remote_cache
set :use_sudo, false

default_run_options[:pty] = true
ssh_options[:forward_agent] = true
ssh_options[:keys] = ["/home/vedant/.ssh/vedanta-key-pair-singapore.pem"]

# set :rvm_ruby_string, :local        # use the same ruby as used locally for deployment
#
# before 'deploy', 'rvm:install_rvm'  # install/update RVM
# before 'deploy', 'rvm:install_ruby' # install Ruby and create gemset (both if missing)

# Disabling bundle --deployment when using gemsets
set :bundle_dir, ''
set :bundle_flags, '--system --quiet'

after "deploy", "deploy:cleanup" # keep only the last 5 releases

namespace :deploy do
  %w[start stop restart].each do |command|
    desc "#{command} unicorn server"
    task command, roles: :app, except: {no_release: true} do
      run "/etc/init.d/unicorn_#{application} #{command}"
    end
  end

  task :setup_config, roles: :app do
    sudo "ln -nfs #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
    sudo "ln -nfs #{current_path}/config/unicorn_init.sh /etc/init.d/unicorn_#{application}"
    run "mkdir -p #{shared_path}/config"
    put File.read("config/database.yml"), "#{shared_path}/config/database.yml"
    puts "Now edit the config files in #{shared_path}."
  end
  after "deploy:setup", "deploy:setup_config"

  task :symlink_config, roles: :app do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
  end
  after "deploy:finalize_update", "deploy:symlink_config"

  desc "Make sure local git is in sync with remote."
  task :check_revision, roles: :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/#{branch}`
      puts "WARNING: HEAD is not the same as origin/#{branch}"
      puts "Run `git push` to sync changes."
      exit # TODO make this a check to exit rather than exit
    end
  end
  before "deploy", "deploy:check_revision"
  before "deploy:setup", "deploy:check_revision"
  before "deploy:cold", "deploy:check_revision"
  # TODO combine above 3 lines
end
