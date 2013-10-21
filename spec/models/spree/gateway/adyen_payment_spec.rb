require 'spec_helper'

module Spree
  describe Gateway::AdyenPayment do
    context "successfully authorized" do
      let(:response) do
        double("Response", psp_reference: "psp", result_code: "accepted", success?: true)
      end

      before do
        subject.stub_chain(:provider, authorise_payment: response)
      end

      it "adds processing api calls to response object" do
        result = subject.authorize(30000, create(:credit_card))
        expect(result.authorization).to eq response.psp_reference
        expect(result.cvv_result['code']).to eq response.result_code
      end
    end

    context "refused" do
      let(:response) do
        double("Response", success?: false, result_code: "refused", refusal_reason: "Not allowed")
      end

      before do
        subject.stub_chain(:provider, authorise_payment: response)
      end

      it "response obj print friendly message" do
        result = subject.authorize(30000, create(:credit_card))
        expect(result.to_s).to include(response.result_code)
        expect(result.to_s).to include(response.refusal_reason)
      end
    end
  end
end
