require 'spec_helper'

module Spree
  describe Gateway::AdyenHPP do
    context "comply with spree payment/processing api" do
      context "void" do
        it "makes response.authorization returns the psp reference" do
          response = double('Response', success?: true, psp_reference: "huhu")
          subject.stub_chain(:provider, cancel_payment: response)

          expect(subject.void("huhu").authorization).to eq "huhu"
        end
      end

      context "capture" do
        it "makes response.authorization returns the psp reference" do
          response = double('Response', success?: true, psp_reference: "huhu")
          subject.stub_chain(:provider, capture_payment: response)

          result = subject.capture(30000, "huhu")
          expect(result.authorization).to eq "huhu"
          expect(result.avs_result).to eq({})
          expect(result.cvv_result).to eq({})
        end
      end
    end
  end
end
