require 'spec_helper'
require 'support/standard_setup'

describe Txbr::EmailTemplate do
  include_context 'standard setup'

  let(:email_template_id) { 'abc123' }
  let(:email_template) { described_class.new(project, email_template_id) }

  let(:body_html) do
    <<~HTML
      <html>
        <head>
          {% assign project_slug = "my_project" %}
          {% assign resource_slug = "my_resource" %}
          {% assign translation_enabled = true %}
          {% connected_content http://my_strings_api.com/ :save strings %}
        </head>
        <body>
          {{strings.header | default: 'Buy our stuff!'}}
          {% if user.gets_discount? %}
            {{strings.discount | default: 'You get a discount'}}
          {% else %}
            {{strings.no_discount | default: 'You get no discount'}}
          {% endif %}
        </body>
      </html>
    HTML
  end

  let(:subject_html) do
    <<~HTML
      {% assign project_slug = "my_project" %}
      {% assign resource_slug = "my_resource" %}
      {% assign translation_enabled = true %}
      {% connected_content http://my_strings_api.com/ :save strings %}
      {{strings.meta.subject_line | default: 'You lucky duck maybe'}}
    HTML
  end

  let(:preheader_html) do
    <<~HTML
      {% assign project_slug = "my_project" %}
      {% assign resource_slug = "my_resource" %}
      {% assign translation_enabled = true %}
      {% connected_content http://my_strings_api.com/ :save strings %}
      {{strings.meta.preheader | default: 'Our stuff is the bomb and you should buy it.'}}
    HTML
  end

  describe '#each_resource' do
    let(:braze_interactions) do
      [{
        request: {
          verb: 'get',
          url: Txbr::BrazeApi::TEMPLATE_INFO_PATH,
          params: { email_template_id: email_template_id }
        },
        response: {
          status: 200,
          body: {
            template_name: 'Super Slick Awesome',
            body: body_html,
            subject: subject_html,
            preheader: preheader_html
          }.to_json
        }
      }]
    end

    it 'extracts and groups all strings with the same project, resource, and prefix' do
      resources = email_template.each_resource.to_a
      expect(resources.size).to eq(1)

      resource = resources.first

      # notice how it combined strings from the subject, preheader,
      # and template (i.e. HTML body)
      expect(resource.phrases).to eq([
        { 'key' => 'header', 'string' => 'Buy our stuff!' },
        { 'key' => 'discount', 'string' => 'You get a discount' },
        { 'key' => 'no_discount', 'string' => 'You get no discount' },
        { 'key' => 'meta.subject_line', 'string' => 'You lucky duck maybe' },
        { 'key' => 'meta.preheader', 'string' => 'Our stuff is the bomb and you should buy it.' }
      ])
    end

    it 'constructs a txgh resource' do
      resource = email_template.each_resource.to_a.first
      tx_resource = resource.tx_resource

      expect(tx_resource.project_slug).to eq('my_project')
      expect(tx_resource.resource_slug).to eq('my_resource')
      expect(tx_resource.source_file).to eq('Super Slick Awesome')
      expect(tx_resource.source_lang).to eq(project.source_lang)
      expect(tx_resource.type).to eq(project.strings_format)
    end

    context 'with translations disabled for the subject' do
      let(:subject_html) do
        super().tap do |subj|
          subj.sub!('translation_enabled = true', 'translation_enabled = false')
        end
      end

      it 'does not include translations for the subject line' do
        expect(email_template.each_resource.to_a.first.phrases).to_not(
          include({ 'key' => 'meta.subject_line', 'string' => 'You lucky duck maybe' })
        )
      end
    end

    context 'when the subject comes from a separate resource' do
      let(:subject_html) do
        super().tap do |subj|
          subj.sub!(
            'resource_slug = "my_resource"',
            'resource_slug = "my_other_resource"'
          )
        end
      end

      it 'includes two resources' do
        resources = email_template.each_resource.to_a
        expect(resources.size).to eq(2)

        expect(resources.first.phrases).to_not(
          include({ 'key' => 'meta.subject_line', 'string' => 'You lucky duck maybe' })
        )

        expect(resources.last.phrases).to eq(
          [{ 'key' => 'meta.subject_line', 'string' => 'You lucky duck maybe' }]
        )
      end
    end
  end
end
