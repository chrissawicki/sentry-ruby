module Sentry
  module LoggingHelper
    def log_error(message)
      logger.error(LOGGER_PROGNAME) { message }
    end

    def log_info(message)
      logger.info(LOGGER_PROGNAME) { message }
    end

    def log_debug(message)
      logger.debug(LOGGER_PROGNAME) { message }
    end

    def log_warn(message)
      logger.warn(LOGGER_PROGNAME) { message }
    end
  end
end
