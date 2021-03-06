module Txbr
  class EmailTemplateHandler
    attr_reader :project

    def initialize(project)
      @project = project
    end

    def each_resource(&block)
      return to_enum(__method__) unless block_given?
      each_template { |tmpl| tmpl.each_resource(&block) }
    end

    private

    def each_template
      return to_enum(__method__) unless block_given?

      project.braze_api.each_email_template do |tmpl|
        yield EmailTemplate.new(project, tmpl['email_template_id'])
      end
    end
  end
end
