require "bundler/capistrano"            # install all the new missing plugins...
require 'capistrano/ext/multistage'     # deploy on all the servers..
# require 'delayed/recipes'               # load this for delayed job..
require "rvm/capistrano"                # if you are using rvm on your server..
require "bundler/setup"
server "54.254.207.154", :app, :web, :db, :primary => true #ip of the server
set :stages, %w{testing production}
set :default_stage, "production"
set :application, "webapp"

set :repository,  "git@bitbucket.org:vedanta/kay.vee.shopping.git"
set :branch, 'master'
set :scm, :git # You can set :scm explicitly or Capistrano will make an intelligent guess based on known version control directory names
set :rails_env, :stage
set :rvm_ruby_string, '2.1.0'             # ruby version you are using...
set :deploy_to, "/home/ubuntu/mundi/"
set :use_sudo, false
set :user, "ubuntu"
set :keep_releases, 3
set :rvm_type, :user
set :git_shallow_clone, 1
set :git_enable_submodules, 1
set :deploy_via, :remote_cache
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`
default_run_options[:pty] = true
ssh_options[:keys] = ["/home/vedant/.ssh/vedanta-key-pair-singapore.pem"]

# role :web, "your web-server here"                          # Your HTTP server, Apache/etc
# role :app, "your app-server here"                          # This may be the same as your `Web` server
# role :db,  "your primary db-server here", :primary => true # This is where Rails migrations will run
# role :db,  "your slave db-server here"

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
    run "ln -sf #{shared_path}/database.yml #{release_path}/config/database.yml"
  end
end