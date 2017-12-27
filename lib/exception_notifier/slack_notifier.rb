module ExceptionNotifier
  class SlackNotifier
    include BacktraceCleaner
    DEFAULT_OPTIONS = {
      username: 'Exception Notifier',
      icon_emoji: ':fire:'
    }
    attr_accessor :slack_options

    def initialize(options)
      self.slack_options = options
    end

    def call(exception, options = {})
      notifier.ping '', message_options(exception, options)
    end

    private

    def notifier
      @notifier ||= Slack::Notifier.new slack_options.fetch(:webhook_url)
    end

    # see https://api.slack.com/docs/formatting
    # see https://api.slack.com/incoming-webhooks
    def message_options(exception, opts)
      env = opts.fetch(:env, {})
      request = env['REQUEST_METHOD'].blank? ? false : ActionDispatch::Request.new(env)

      option_for_attachments = {
        color: 'danger',
        title: exception.message,
        fields: attachment_fields(exception, request),
        mrkdwn_in: %w(text title fallback fields)
      }
      option_for_attachments[:text] = current_url(request) if request

      DEFAULT_OPTIONS.merge(slack_options).merge(opts).slice(:channel, :username, :icon_emoji).tap do |options|
        options[:attachments] = [option_for_attachments]
      end
    end

    # see https://api.slack.com/docs/attachments
    def attachment_fields(exception, request = nil)
      fields = []

      if defined?(Rails)
        fields << attachment_field('Project', Rails.application.class.parent_name, short: true)
        fields << attachment_field('Environment', Rails.env, short: true)
      end

      fields << attachment_field('Backtrace', exception_backtrace(exception))

      if request
        fields << attachment_field('Data', additional_data(request.env.fetch('exception_notifier.exception_data', {})))
        fields << attachment_field('Parameters', additional_data(request.filtered_parameters))
      end

      fields
    end

    def attachment_field(title, value, short: false)
      { title: title, value: value, short: short }
    end

    def exception_backtrace(exception)
      clean_backtrace(exception).first(10).join("\n")
    end

    def exception_backtrace(exception)
      clean_backtrace(exception).first(10).map { |s| "> #{s}" }.join("\n")
    end

    def current_url(request)
      "*#{request.request_method}* #{request.original_url}"
    end

    def additional_data(parameters)
      parameters.map { |key, value| ">  *#{key}*: #{value}" }.join("\n")
    end
  end
end
