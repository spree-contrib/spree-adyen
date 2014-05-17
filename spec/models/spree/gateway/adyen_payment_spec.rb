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

      let(:cc) { create(:credit_card) }

      it "adds processing api calls to response object" do
        expect {
          subject.authorize(30000, cc, options)
        }.not_to raise_error

        cc.gateway_customer_profile_id = "123"
        expect {
          subject.authorize(30000, cc, options)
        }.not_to raise_error
      end

      it "user order email as shopper reference when theres no user" do
        cc.gateway_customer_profile_id = "123"
        options[:customer_id] = nil

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

      let(:details_response) do
        double("List", details: [
          { card: { expiry_date: Time.now, number: "1111" },
            recurring_detail_reference: "123432423" }
        ])
      end

      before do
        subject.stub_chain(:provider, authorise_payment: response)
        subject.stub_chain(:provider, list_recurring_details: details_response)
      end

      it "authorizes payment to set up recurring transactions" do
        payment.source.gateway_customer_profile_id = nil
        subject.create_profile payment
        expect(payment.source.gateway_customer_profile_id).to eq details_response.details.last[:recurring_detail_reference]
      end
    end

    context "real external profile creation", external: true do
      before do
        subject.preferred_merchant_account = test_credentials["merchant_account"]
        subject.preferred_api_username = test_credentials["api_username"]
        subject.preferred_api_password = test_credentials["api_password"]
      end

      let(:order) do
        user = stub_model(LegacyUser, email: "spree@example.com", id: rand(50))
        stub_model(Order, id: 1, number: "R#{Time.now.to_i}-test", email: "spree@example.com", last_ip_address: "127.0.0.1", user: user)
      end

      context 'with an associated user' do
        pending "sets last recurring detail reference returned on payment source" do
          subject.save

          payment = Payment.create! do |p|
            p.order = order
            p.amount = 1
            p.source = credit_card
            p.payment_method = subject
          end

          expect(payment.source.gateway_customer_profile_id).to be_present
        end
      end

      context 'without an associated user' do
        let(:order) do
          stub_model(Order, id: 1, number: "R2342345435", last_ip_address: "127.0.0.1")
        end

        pending "sets last recurring detail reference returned on payment source" do
          subject.save

          payment = Payment.create! do |p|
            p.order = order
            p.amount = 1
            p.source = credit_card
            p.payment_method = subject
          end

          expect(payment.source.gateway_customer_profile_id).to be_present
        end
      end

      context "3-D enrolled credit card" do
        let(:credit_card) do
          CreditCard.create! do |cc|
            cc.name = "Washington Braga"
            cc.number = "4212 3456 7890 1237"
            cc.month = "06"
            cc.year = "2016"
            cc.verification_value = "737"
          end
        end

        let(:env) do
          {
            "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:29.0) Gecko/20100101 Firefox/29.0",
            "HTTP_ACCEPT"=> "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
          }
        end

        def set_up_payment
          Payment.create! do |p|
            p.order = order
            p.amount = 1
            p.source = credit_card
            p.payment_method = subject
            p.request_env = env
          end
        end

        it "raises custom exception" do
          subject.save

          VCR.use_cassette("3D-Secure") do
            expect {
              set_up_payment
            }.to raise_error Adyen::Enrolled3DError
          end
        end

        it "doesn't persist new payments" do
          subject.save

          VCR.use_cassette("3D-Secure") do
            payments = Payment.count
            expect { set_up_payment }.to raise_error Adyen::Enrolled3DError
            expect(payments).to eq Payment.count
          end
        end

        it "authorises with payment 3d request" do
          md = test_credentials["md"]
          pa_response = test_credentials["pa_response"]
          ip = "127.0.0.1"

          VCR.use_cassette("3D-Secure-authorise") do
            expect(subject.authorise3d(md, pa_response, ip, env)).to be_success
          end
        end
      end
    end
  end
end
