# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require 'rspec/rails'
require 'ffaker'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].each {|f| require f }

require 'spree/testing_support/factories'
require 'spree/testing_support/controller_requests'
require 'spree/testing_support/url_helpers'

module Spree
  module Adyen
    module TestHelper
      def test_credentials
        @tc ||= YAML::load_file(File.new("#{Engine.config.root}/config/credentials.yml"))
      end
    end
  end
end

RSpec.configure do |config|
  config.color = true
  config.mock_with :rspec

  config.use_transactional_fixtures = true

  config.include Spree::TestingSupport::ControllerRequests
  config.include FactoryGirl::Syntax::Methods
  config.include Spree::TestingSupport::UrlHelpers

  config.filter_run_excluding :external => true

  config.include Spree::Adyen::TestHelper
end

VCR.configure do |c|
  # c.allow_http_connections_when_no_cassette = true
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
end
