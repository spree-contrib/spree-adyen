module Spree
  module Adyen
    class Enrolled3DError < StandardError
      attr_reader :response, :issuer_url, :pa_request, :md, :gateway, :gateway_options

      def initialize(response, gateway, gateway_options={})
        @response = response

        @issuer_url = response.issuer_url
        @pa_request = response.pa_request
        @md = response.md
        @gateway = gateway
        @gateway_options = gateway_options
      end

      def messsage
        response.to_s
      end
    end
  end
end
