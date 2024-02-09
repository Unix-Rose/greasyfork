if Rails.env.production?
  require 'sidekiq-unique-jobs'

  Sidekiq.configure_client do |config|
    config.redis = { url: 'redis://192.168.166.212:6379/0' }
    config.client_middleware do |chain|
      chain.add SidekiqUniqueJobs::Middleware::Client
    end
  end
end

if Rails.env.production?
  require 'sidekiq/worker_killer'

  Sidekiq.configure_server do |config|
    config.on(:startup) do
      [ScriptDeleteJob, ConsecutiveBadRatingsJob, UserFloodJob, DiscussionReadCleanupJob, BannedUserDeleteJob, ScriptPageViewUpdateJob]
        .reject(&:enqueued?)
        .each(&:perform_later)

      config.server_middleware do |chain|
        chain.add Sidekiq::WorkerKiller,
                  max_rss: 15_000 * 0.75 / 2, # 75% of memory spread across n processes
                  shutdown_wait: 90
        chain.add SidekiqUniqueJobs::Middleware::Server
      end

      config.client_middleware do |chain|
        chain.add SidekiqUniqueJobs::Middleware::Client
      end
    end
  end
end
