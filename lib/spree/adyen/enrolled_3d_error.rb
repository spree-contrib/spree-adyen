module Spree
  module Adyen
    class Enrolled3DError < StandardError
      attr_reader :response, :issuer_url, :pa_request, :md

      def initialize(response)
        @response = response

        @issuer_url = response.issuer_url
        @pa_request = response.pa_request
        @md = response.md
      end

      def messsage
        response.to_s
      end
    end
  end
end
