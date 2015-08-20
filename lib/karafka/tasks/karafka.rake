namespace :karafka do
  desc 'Runs a single Karafka processing instance'
  task :run do
    Karafka::App.run
  end

  desc 'Runs a single Sidekiq worker for Karafka'
  task :sidekiq do
    require_file = Karafka::App.root.join('app.rb')
    config_file = Karafka::App.root.join('/config/sidekiq.yml')
    system ("bundle exec sidekiq -r #{require_file} -C #{config_file}")
  end

  desc 'Creates whole minimal app structure'
  task :install do
    require 'fileutils'

    %w(
      app/models
      app/controllers
      config/
    ).each do |dir|
      FileUtils.mkdir_p dir
    end

    {
      'app.rb.example' => 'app.rb',
      'rakefile.rb.example' => 'rakefile.rb',
      'sidekiq.yml.example' => 'config/sidekiq.yml.example'
    }.each do |source, target|
      FileUtils.cp_r(
        Karafka.core_root.join("templates/#{source}"),
        Karafka::App.root.join(target)
      )
    end
  end
end
