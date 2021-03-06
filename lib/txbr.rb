require 'liquid'

module Txbr
  autoload :Application,            'txbr/application'
  autoload :BrazeApi,               'txbr/braze_api'
  autoload :Commands,               'txbr/commands'
  autoload :Config,                 'txbr/config'
  autoload :EmailTemplate,          'txbr/email_template'
  autoload :EmailTemplateComponent, 'txbr/email_template_component'
  autoload :EmailTemplateHandler,   'txbr/email_template_handler'
  autoload :Project,                'txbr/project'
  autoload :RequestMethods,         'txbr/request_methods'
  autoload :StringsManifest,        'txbr/strings_manifest'
  autoload :Uploader,               'txbr/uploader'
  autoload :Utils,                  'txbr/utils'

  class BrazeApiError < StandardError
    attr_reader :status_code

    def initialize(message, status_code)
      super(message)
      @status_code = status_code
    end
  end

  class BrazeUnauthorizedError < BrazeApiError
    def initialize(message)
      super(message, 401)
    end
  end

  class BrazeNotFoundError < BrazeApiError
    def initialize(message)
      super(message, 404)
    end
  end

  class << self
    def handler_for(project)
      handlers[project.handler_id].new(project)
    end

    def register_handler(id, klass)
      handlers[id] = klass
    end

    private

    def handlers
      @handlers ||= {}
    end
  end

  Txbr.register_handler('email-templates', Txbr::EmailTemplateHandler)


  class ConnectedContentTag < Liquid::Tag
    # This is a regular expression to pull out the variable in
    # which to store the value returned from the call made by
    # the connected_content filter. For example, if
    # connected_content makes a request to http://foo.com and is
    # told to store the results in a variable called "strings",
    # the API response will then be accessible via the normal
    # Liquid variable mechanism, i.e. {{...}}. Say the API at
    # foo.com returned something like {"bar":"baz"}, then the
    # template might contain {{strings.bar}}, which would print
    # out "baz".
    PREFIX_RE = /:save\s+(#{Liquid::Lexer::IDENTIFIER})/

    attr_reader :tag_name, :prefix

    def initialize(tag_name, arg, *)
      @tag_name = tag_name
      @prefix = arg.match(PREFIX_RE).captures.first
    end
  end

  Liquid::Template.register_tag(:connected_content, ConnectedContentTag)
end
