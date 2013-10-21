require 'spec_helper'

module Spree
  describe Gateway::AdyenHPP do
    it "makes response.authorization returns the response_code" do
      response = double('Response')
      subject.stub_chain(:provider, cancel_payment: response)
      expect(subject.void("huhu").authorization).to eq "huhu"
    end
  end
end
