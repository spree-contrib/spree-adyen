require 'spec_helper'

module Spree
  describe AdyenRedirectController do
    let(:order) { create(:order_with_line_items, state: "payment") }

    context "Adyen HPP Gateway" do
      def params
        { "merchantReference"=>"R183301255",
          "skinCode"=>"Nonenone",
          "shopperLocale"=>"en_GB",
          "paymentMethod"=>"visa",
          "authResult"=>"AUTHORISED",
          "pspReference"=>"8813824003752247",
          "merchantSig"=>"erewrwerewrewrwer" }
      end

      let(:payment_method) { Gateway::AdyenHPP.create(name: "Adyen") }

      before do
        expect(controller).to receive(:current_order).and_return order
        expect(controller).to receive(:check_signature)
        expect(controller).to receive(:payment_method).and_return payment_method
      end

      it "create payment" do
        expect {
          spree_get :confirm, params
        }.to change { Payment.count }.by(1)
      end

      it "sets payment attributes properly" do
        spree_get :confirm, params
        payment = Payment.last

        expect(payment.amount.to_f).to eq order.total.to_f
        expect(payment.payment_method).to eq payment_method
        expect(payment.response_code).to eq params['pspReference']
      end

      it "redirects to order complete page" do
        spree_get :confirm, params
        expect(response).to redirect_to spree.order_path(order, :token => order.guest_token)
      end

      pending "test check signature filter"
      pending "grab payment method by parameter (possibly merchantReturnData passed via session payment params)"
    end

    context "Adyen 3-D redirect" do
      let(:env) do
        {
          "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:29.0) Gecko/20100101 Firefox/29.0",
          "HTTP_ACCEPT"=> "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        }
      end

      context "stubbing Adyen API" do
        let(:params) do
          { MD: "Sooo", PaRes: "Wat" }
        end

        let!(:gateway) { Gateway::AdyenPaymentEncrypted.create!(name: "Adyen") }

        before do
          expect(controller).to receive(:current_order).and_return order

          expect(Gateway::AdyenPaymentEncrypted).to receive(:find).and_return gateway
          expect(gateway).to receive(:authorise3d).and_return double("Response", success?: true, psp_reference: 1)
          gateway.stub_chain :provider, list_recurring_details: double("RecurringDetails", details: [])
        end

        it "redirects user if no recurring detail is returned" do
          spree_get :authorise3d, params, { adyen_gateway_name: gateway.class.name, adyen_gateway_id: gateway.id }
          expect(response).to redirect_to redirect_to spree.checkout_state_path(order.state)
        end

        it "payment need to be in processing state so it's not authorised twice" do
          details = { card: { expiry_date: 1.year.from_now, number: "1111" }, recurring_detail_reference: "123432423" }
          gateway.stub_chain :provider, list_recurring_details: double("RecurringDetails", details: [details])

          spree_get :authorise3d, params, { adyen_gateway_name: gateway.class.name, adyen_gateway_id: gateway.id }
          expect(Payment.last.state).to eq "processing"
        end
      end

      context "reaching Adyen API", external: true do
        let(:params) do
          { MD: test_credentials["controller_md"], PaRes: test_credentials["controller_pa_response"] }
        end

        let!(:gateway) do
          Gateway::AdyenPaymentEncrypted.create!(
            name: "Adyen",
            preferred_api_username: test_credentials["api_username"],
            preferred_api_password: test_credentials["api_password"],
            preferred_merchant_account: test_credentials["merchant_account"]
          )
        end

        before do
          order.user_id = 1
          controller.stub(current_order: order)

          ActionController::TestRequest.any_instance.stub(:ip).and_return("127.0.0.1")
          ActionController::TestRequest.any_instance.stub_chain(:headers, env: env)
        end

        it "redirects user to confirm step" do
          VCR.use_cassette("3D-Secure-authorise-redirect-controller") do
            spree_get :authorise3d, params, { adyen_gateway_name: gateway.class.name, adyen_gateway_id: gateway.id }
            expect(response).to redirect_to redirect_to spree.checkout_state_path("confirm")
          end
        end

        it "set up payment" do
          VCR.use_cassette("3D-Secure-authorise-redirect-controller") do
            expect {
              spree_get :authorise3d, params, { adyen_gateway_name: gateway.class.name, adyen_gateway_id: gateway.id }
            }.to change { Payment.count }.by(1)
          end
        end

        it "set up credit card with recurring details" do
          VCR.use_cassette("3D-Secure-authorise-redirect-controller") do
            expect {
              spree_get :authorise3d, params, { adyen_gateway_name: gateway.class.name, adyen_gateway_id: gateway.id }
            }.to change { CreditCard.count }.by(1)

            expect(CreditCard.last.gateway_customer_profile_id).to be_present
          end
        end
      end
    end
  end
end
