# frozen_string_literal: true

module Gitlab
  module Memory
    class Watchdog
      class Configurator
        DEFAULT_PUMA_WORKER_RSS_LIMIT_MB = 1200
        DEFAULT_SLEEP_INTERVAL_S = 60
        DEFAULT_SIDEKIQ_SLEEP_INTERVAL_S = 3
        MIN_SIDEKIQ_SLEEP_INTERVAL_S = 2
        DEFAULT_MAX_STRIKES = 5
        DEFAULT_MAX_HEAP_FRAG = 0.5
        DEFAULT_MAX_MEM_GROWTH = 3.0
        # grace_time / sleep_interval = max_strikes allowed for Sidekiq process to violate defined limits.
        DEFAULT_SIDEKIQ_GRACE_TIME_S = 300

        class << self
          def configure_for_puma
            ->(config) do
              config.handler = Gitlab::Memory::Watchdog::PumaHandler.new
              config.write_heap_dumps = write_heap_dumps?
              config.sleep_time_seconds = ENV.fetch('GITLAB_MEMWD_SLEEP_TIME_SEC', DEFAULT_SLEEP_INTERVAL_S).to_i
              config.monitors(&configure_monitors_for_puma)
            end
          end

          def configure_for_sidekiq
            ->(config) do
              config.handler = Gitlab::Memory::Watchdog::TermProcessHandler.new
              config.write_heap_dumps = write_heap_dumps?
              config.sleep_time_seconds = sidekiq_sleep_time
              config.monitors(&configure_monitors_for_sidekiq)
              config.event_reporter = EventReporter.new(logger: ::Sidekiq.logger)
            end
          end

          private

          def write_heap_dumps?
            Gitlab::Utils.to_boolean(ENV['GITLAB_MEMWD_DUMP_HEAP'], default: false)
          end

          def configure_monitors_for_puma
            ->(stack) do
              max_strikes = ENV.fetch('GITLAB_MEMWD_MAX_STRIKES', DEFAULT_MAX_STRIKES).to_i

              if Gitlab::Utils.to_boolean(ENV['DISABLE_PUMA_WORKER_KILLER'])
                max_heap_frag = ENV.fetch('GITLAB_MEMWD_MAX_HEAP_FRAG', DEFAULT_MAX_HEAP_FRAG).to_f
                max_mem_growth = ENV.fetch('GITLAB_MEMWD_MAX_MEM_GROWTH', DEFAULT_MAX_MEM_GROWTH).to_f

                # stack.push MonitorClass, args*, max_strikes:, kwargs**, &block
                stack.push Gitlab::Memory::Watchdog::Monitor::HeapFragmentation,
                           max_heap_fragmentation: max_heap_frag,
                           max_strikes: max_strikes

                stack.push Gitlab::Memory::Watchdog::Monitor::UniqueMemoryGrowth,
                           max_mem_growth: max_mem_growth,
                           max_strikes: max_strikes
              else
                memory_limit = ENV.fetch('PUMA_WORKER_MAX_MEMORY', DEFAULT_PUMA_WORKER_RSS_LIMIT_MB).to_i

                stack.push Gitlab::Memory::Watchdog::Monitor::RssMemoryLimit,
                           memory_limit_bytes: memory_limit.megabytes,
                           max_strikes: max_strikes
              end
            end
          end

          def sidekiq_sleep_time
            [
              ENV.fetch('SIDEKIQ_MEMORY_KILLER_CHECK_INTERVAL', DEFAULT_SIDEKIQ_SLEEP_INTERVAL_S).to_i,
              MIN_SIDEKIQ_SLEEP_INTERVAL_S
            ].max
          end

          def configure_monitors_for_sidekiq
            ->(stack) do
              if ENV['SIDEKIQ_MEMORY_KILLER_MAX_RSS'].to_i.nonzero?
                soft_limit_bytes = ENV['SIDEKIQ_MEMORY_KILLER_MAX_RSS'].to_i.kilobytes
                grace_time = ENV.fetch('SIDEKIQ_MEMORY_KILLER_GRACE_TIME', DEFAULT_SIDEKIQ_GRACE_TIME_S).to_i
                max_strikes = grace_time / sidekiq_sleep_time

                stack.push Gitlab::Memory::Watchdog::Monitor::RssMemoryLimit,
                           memory_limit_bytes: soft_limit_bytes,
                           max_strikes: max_strikes.to_i,
                           monitor_name: :rss_memory_soft_limit
              end

              if ENV['SIDEKIQ_MEMORY_KILLER_HARD_LIMIT_RSS'].to_i.nonzero?
                hard_limit_bytes = ENV['SIDEKIQ_MEMORY_KILLER_HARD_LIMIT_RSS'].to_i.kilobytes

                stack.push Gitlab::Memory::Watchdog::Monitor::RssMemoryLimit,
                           memory_limit_bytes: hard_limit_bytes,
                           max_strikes: 0,
                           monitor_name: :rss_memory_hard_limit
              end
            end
          end
        end
      end
    end
  end
end
