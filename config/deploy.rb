# require "bundler/capistrano"            # install all the new missing plugins...
# require "capistrano/ext/multistage"     # deploy on all the servers..
# # require "delayed/recipes"               # load this for delayed job..
# require "rvm/capistrano"                # if you are using rvm on your server..
# require "bundler/setup"
server "54.254.208.254", :app, :web, :db, :primary => true #ip of the server
set :stages, %w{testing production}
set :default_stage, "production"
set :application, "manndi"

set :repository,  "git@bitbucket.org:vedanta/manndi.git"
set :branch, "master"
set :scm, :git # You can set :scm explicitly or Capistrano will make an intelligent guess based on known version control directory names
set :migrate_target,  :current
set :ssh_options,     { :forward_agent => true }
set :deploy_to, "/home/ubuntu/#{application}"
set :normalize_asset_timestamps, false
set :rails_env, "production"

set :rvm_ruby_string, '2.1.0'             # ruby version you are using...

set :use_sudo, false
set :user, "ubuntu"

# set :keep_releases, 3
set :rvm_type, :user
set :git_shallow_clone, 1
set :git_enable_submodules, 1
set :deploy_via, :remote_cache

default_run_options[:pty] = true
default_run_options[:shell] = "bash" # "/bin/bash --login"
default_environment["RAILS_ENV"] = "production"
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
# namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
#   end
#   task :config_symlink do
#     run "ln -sf #{shared_path}/config/database.yml #{release_path}/config/database.yml"
#   end
# end

# namespace :unicorn do
#   desc "Zero-downtime restart of Unicorn"
#   task :restart, except: { no_release: true } do
#     run "kill -s USR2 `cat /tmp/unicorn.#{application}.pid`"
#   end
#
#   desc "Start unicorn"
#   task :start, except: { no_release: true } do
#     run "cd #{current_path} ; bundle exec unicorn_rails -c config/unicorn.rb -D"
#   end
#
#   desc "Stop unicorn"
#   task :stop, except: { no_release: true } do
#     run "kill -s QUIT `cat /tmp/unicorn.#{application}.pid`"
#   end
# end
#
# after "deploy:restart", "unicorn:restart"

namespace :deploy do
  desc "Deploy your application"
  task :default do
    update
    restart
  end

  desc "Setup your git-based deployment app"
  task :setup, :except => { :no_release => true } do
    dirs = [deploy_to, shared_path]
    dirs += shared_children.map { |d| File.join(shared_path, d) }
    run "#{try_sudo} mkdir -p #{dirs.join(' ')} && #{try_sudo} chmod g+w #{dirs.join(' ')}"
    run "git clone #{repository} #{current_path}"
  end

  task :cold do
    update
    migrate
  end

  task :update do
    transaction do
      update_code
    end
  end

  desc "Update the deployed code."
  task :update_code, :except => { :no_release => true } do
    run "cd #{current_path}; git fetch origin; git reset --hard #{branch}"
    finalize_update
  end

  desc "Update the database (overwritten to avoid symlink)"
  task :migrations do
    transaction do
      update_code
    end
    migrate
    restart
  end

  task :finalize_update, :except => { :no_release => true } do
    run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)

    # mkdir -p is making sure that the directories are there for some SCM's that don't
    # save empty folders
    run <<-CMD
      rm -rf #{latest_release}/log #{latest_release}/public/system #{latest_release}/tmp/pids &&
      mkdir -p #{latest_release}/public &&
      mkdir -p #{latest_release}/tmp &&
      ln -s #{shared_path}/log #{latest_release}/log &&
      ln -s #{shared_path}/system #{latest_release}/public/system &&
      ln -s #{shared_path}/pids #{latest_release}/tmp/pids &&
      ln -sf #{shared_path}/database.yml #{latest_release}/config/database.yml
    CMD

    if fetch(:normalize_asset_timestamps, true)
      stamp = Time.now.utc.strftime("%Y%m%d%H%M.%S")
      asset_paths = fetch(:public_children, %w(images stylesheets javascripts)).map { |p| "#{latest_release}/public/#{p}" }.join(" ")
      run "find #{asset_paths} -exec touch -t #{stamp} {} ';'; true", :env => { "TZ" => "UTC" }
    end
  end

  desc "Zero-downtime restart of Unicorn"
  task :restart, :except => { :no_release => true } do
    run "kill -s USR2 `cat /tmp/unicorn.my_site.pid`"
  end

  desc "Start unicorn"
  task :start, :except => { :no_release => true } do
    run "cd #{current_path} ; bundle exec unicorn_rails -c config/unicorn.rb -D"
  end

  desc "Stop unicorn"
  task :stop, :except => { :no_release => true } do
    run "kill -s QUIT `cat /tmp/unicorn.my_site.pid`"
  end

  namespace :rollback do
    desc "Moves the repo back to the previous version of HEAD"
    task :repo, :except => { :no_release => true } do
      set :branch, "HEAD@{1}"
      deploy.default
    end

    desc "Rewrite reflog so HEAD@{1} will continue to point to at the next previous release."
    task :cleanup, :except => { :no_release => true } do
      run "cd #{current_path}; git reflog delete --rewrite HEAD@{1}; git reflog delete --rewrite HEAD@{1}"
    end

    desc "Rolls back to the previously deployed version."
    task :default do
      rollback.repo
      rollback.cleanup
    end
  end
end

def run_rake(cmd)
  run "cd #{current_path}; #{rake} #{cmd}"
end
