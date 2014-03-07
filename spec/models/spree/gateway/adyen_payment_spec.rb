require 'spec_helper'

module Spree
  describe Gateway::AdyenPayment do
    let(:response) do
      double("Response", psp_reference: "psp", result_code: "accepted", success?: true)
    end

    context "successfully authorized" do
      before do
        subject.stub_chain(:provider, authorise_payment: response)
      end

      it "adds processing api calls to response object" do
        result = subject.authorize(30000, create(:credit_card))

        expect(result.authorization).to eq response.psp_reference
        expect(result.cvv_result['code']).to eq response.result_code
      end
    end

    context "ensure adyen validations goes fine" do
      let(:options) do
        { :order_id => 17,
          :email => "surf@uk.com",
          :customer_id => 1,
          :ip => "127.0.0.1" }
      end

      before do
        subject.preferred_merchant_account = "merchant"
        subject.preferred_api_username = "admin"
        subject.preferred_api_password = "123"

        # Watch out as we're stubbing private method here to avoid reaching network
        # we might need to stub another method in future adyen gem versions
        ::Adyen::API::PaymentService.any_instance.stub(make_payment_request: response)
      end

      it "adds processing api calls to response object" do
        cc = create(:credit_card)
        expect {
          subject.authorize(30000, cc, options)
        }.not_to raise_error

        cc.gateway_customer_profile_id = "123"
        expect {
          subject.authorize(30000, cc, options)
        }.not_to raise_error
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

    context "profile creation" do
      let(:payment) { create(:payment) }

      before do
        subject.stub_chain(:provider, authorise_payment: response)
      end

      it "authorizes payment to set up recurring transactions" do
        payment.source.gateway_customer_profile_id = nil
        subject.create_profile payment
      end
    end
  end
end
