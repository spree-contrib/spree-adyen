module Spree
  module Adyen
    class HPPRedirectError < StandardError
      attr_reader :source

      def initialize(source)
        @source = source
      end

      def messsage
        source.to_s
      end
    end
  end
end