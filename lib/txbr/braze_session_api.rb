require 'faraday'
require 'faraday_middleware'

module Txbr
  class BrazeSessionApi
    EMAIL_TEMPLATE_BATCH_SIZE = 35

    include RequestMethods

    attr_reader :session, :app_group_id

    def initialize(session, app_group_id, connection: nil)
      @session = session
      @app_group_id = app_group_id
      @connection = connection
    end

    def each_email_template(start: 0, &block)
      return to_enum(__method__, start: start) unless block_given?

      loop do
        templates = get_json(
          'engagement/email_templates',
          start: start,
          limit: EMAIL_TEMPLATE_BATCH_SIZE
        )

        templates['results'].each(&block)
        start += templates['results'].size
        break if templates['results'].size < EMAIL_TEMPLATE_BATCH_SIZE
      end
    end

    def get_email_template_details(email_template_id:)
      get_json("engagement/email_templates/#{email_template_id}")
    end

    private

    def act(*args)
      retried = false

      begin
        super(*args, { cookie: "_session_id=#{session.session_id}" })
      rescue BrazeUnauthorizedError => e
        raise e if retried
        reset!
        retried = true
        retry
      end
    end

    def reset!
      session.reset!
    end

    def connection
      @connection ||= begin
        options = {
          url: session.api_url,
          params: { app_group_id: app_group_id }
        }

        Faraday.new(options) do |faraday|
          faraday.request(:json)
          faraday.response(:logger)
          faraday.use(FaradayMiddleware::FollowRedirects)
          faraday.adapter(:net_http)
        end
      end
    end
  end
end