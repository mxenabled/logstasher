module LogStasher
  class Railtie < ::Rails::Railtie
    config.logstasher = ::ActiveSupport::OrderedOptions.new
    config.logstasher.enabled = false
    config.logstasher.include_parameters = true
    config.logstasher.serialize_parameters = true
    config.logstasher.silence_standard_logging = false
    config.logstasher.logger = nil
    config.logstasher.log_level = ::Logger::INFO

    config.logstasher.metadata  = {}
    config.before_initialize do
      options = config.logstasher

      ::LogStasher.enabled                  = options.enabled
      ::LogStasher.include_parameters       = options.include_parameters
      ::LogStasher.serialize_parameters     = options.serialize_parameters
      ::LogStasher.silence_standard_logging = options.silence_standard_logging
      ::LogStasher.logger                   = options.logger
      ::LogStasher.logger.level             = options.log_level
      ::LogStasher.metadata                 = options.metadata
    end

    config.after_initialize do
      if ::LogStasher.enabled? && !::LogStasher.silence_standard_logging?
        ::ActiveSupport.on_load(:action_controller) do
          require "logstasher/log_subscriber"
          require "logstasher/context_wrapper"

          include ::LogStasher::ContextWrapper
        end
      end
    end
  end
end
