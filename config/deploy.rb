require "bundler/capistrano"            # install all the new missing plugins...
require 'capistrano/ext/multistage'     # deploy on all the servers..
# require 'delayed/recipes'               # load this for delayed job..
require "rvm/capistrano"                # if you are using rvm on your server..
require "bundler/setup"
server "54.254.207.154", :app, :web, :db, :primary => true #ip of the server
set :stages, %w{testing production}
set :default_stage, "production"
set :application, "manndi"

set :repository,  "git@bitbucket.org:vedanta/manndi.git"
set :branch, 'master'
set :scm, :git # You can set :scm explicitly or Capistrano will make an intelligent guess based on known version control directory names
set :rails_env, :stage
set :rvm_ruby_string, '2.1.0'             # ruby version you are using...
set :deploy_to, "/home/ubuntu/#{application}"
set :use_sudo, false
set :user, "ubuntu"
set :keep_releases, 3
set :rvm_type, :user
set :git_shallow_clone, 1
set :git_enable_submodules, 1
set :deploy_via, :remote_cache
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

default_run_options[:pty] = true
default_run_options[:shell] = '/bin/bash --login'
default_environment["RAILS_ENV"] = 'production'
ssh_options[:keys] = ["/home/vedant/.ssh/vedanta-key-pair-singapore.pem"]

# task :symlink_database_yml do
#   run "rm #{release_path}/config/database.yml"
#   run "ln -sfn #{shared_path}/config/database.yml #{release_path}/config/database.yml"
# end
# after "bundle:install", "symlink_database_yml"

# if you want to clean up old releases on each deploy uncomment this:
after "deploy:restart", "deploy:cleanup"

before "deploy:assets:precompile","deploy:config_symlink"#,"deploy:system_symlink"

after "deploy:update_code","deploy:migrate"

after "deploy:update", "deploy:cleanup" #clean up temp files etc.
# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
  task :config_symlink do
    run "ln -sf #{shared_path}/config/database.yml #{release_path}/config/database.yml"
  end
end

namespace :unicorn do
  desc "Zero-downtime restart of Unicorn"
  task :restart, except: { no_release: true } do
    run "kill -s USR2 `cat /tmp/unicorn.#{application}.pid`"
  end

  desc "Start unicorn"
  task :start, except: { no_release: true } do
    run "cd #{current_path} ; bundle exec unicorn_rails -c config/unicorn.rb -D"
  end

  desc "Stop unicorn"
  task :stop, except: { no_release: true } do
    run "kill -s QUIT `cat /tmp/unicorn.#{application}.pid`"
  end
end

after "deploy:restart", "unicorn:restart"