# frozen_string_literal: true
require "delayed_job"

module Sentry
  module DelayedJob
    class Plugin < ::Delayed::Plugin
      callbacks do |lifecycle|
        lifecycle.around(:invoke_job) do |job, *args, &block|
          next block.call(job, *args) unless Sentry.initialized?

          Sentry.with_scope do |scope|
            scope.set_extras(**generate_extra(job))
            scope.set_tags("delayed_job.queue" => job.queue, "delayed_job.id" => job.id.to_s)

            begin
              block.call(job, *args)
            rescue Exception => e
              capture_exception(e, job)

              raise
            end
          end
        end
      end

      def self.capture_exception(exception, job)
        Sentry::DelayedJob.capture_exception(exception, hint: { background: false }) if report?(job)
      end

      def self.generate_extra(job)
        extra = {
          "delayed_job.id": job.id.to_s,
          "delayed_job.priority": job.priority,
          "delayed_job.attempts": job.attempts,
          "delayed_job.run_at": job.run_at,
          "delayed_job.locked_at": job.locked_at,
          "delayed_job.locked_by": job.locked_by,
          "delayed_job.queue": job.queue,
          "delayed_job.created_at": job.created_at,
          "delayed_job.last_error": job.last_error&.byteslice(0..1000),
          "delayed_job.handler": job.handler&.byteslice(0..1000)
        }

        if job.payload_object.respond_to?(:job_data)
          job.payload_object.job_data.each do |key, value|
            extra[:"active_job.#{key}"] = value
          end
        end

        extra
      end

      def self.report?(job)
        return true unless Sentry.configuration.delayed_job.report_after_job_retries

        # We use the predecessor because the job's attempts haven't been increased to the new
        # count at this point.
        job.attempts >= Delayed::Worker.max_attempts.pred
      end
    end
  end
end

Delayed::Worker.plugins << Sentry::DelayedJob::Plugin
