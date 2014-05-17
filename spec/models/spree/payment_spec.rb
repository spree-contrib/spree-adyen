require 'spec_helper'

module Spree
  describe Payment do
    shared_examples "creates profile on payment creation" do
      let(:order) { create(:order) }

      let(:details_response) do
        card = { card: { expiry_date: 1.year.from_now, number: "1111" }, recurring_detail_reference: "123432423" }
        double("List", details: [card])
      end

      let(:response) do
        double("Response", psp_reference: "psp", result_code: "accepted", success?: true)
      end

      before do
        payment_method.stub_chain(:provider, authorise_payment: response)
        payment_method.stub_chain(:provider, list_recurring_details: details_response)
      end

      specify do
        Payment.create! do |p|
          p.order_id = order.id
          p.amount = order.total
          p.source = credit_card
          p.payment_method = payment_method
        end

        expect(credit_card.reload.gateway_customer_profile_id).not_to be_empty
      end
    end

    context "Adyen Payments" do
      let(:payment_method) do
        Gateway::AdyenPayment.create(
          name: "Adyen",
          environment: "test",
          preferred_merchant_account: "Test",
          preferred_api_username: "Test",
          preferred_api_password: "Test"
        )
      end

      let(:credit_card) do
        CreditCard.create! do |cc|
          cc.name = "Washington"
          cc.number = "4111111111111111"
          cc.month = "06"
          cc.year = "2016"
          cc.verification_value = "737"
        end
      end

      include_examples "creates profile on payment creation"

      it "voids payments" do
        payment = Payment.create! do |p|
          p.order_id = order.id
          p.amount = order.total
          p.source = credit_card
          p.payment_method = payment_method
        end

        payment_method.stub_chain(:provider, cancel_payment: response)
        expect(payment.void_transaction!).to be
      end

      it "refund payments" do
        payment = Payment.create! do |p|
          p.order_id = order.id
          p.amount = order.total
          p.source = credit_card
          p.payment_method = payment_method
        end

        payment_method.stub_chain(:provider, refund_payment: response)
        expect(payment.credit!).to be_a Spree::Payment
      end
    end

    context "Adyen Payment Encrypted" do
      let(:payment_method) do
        Gateway::AdyenPaymentEncrypted.create(
          name: "Adyen",
          environment: "test",
          preferred_merchant_account: "Test",
          preferred_api_username: "Test",
          preferred_api_password: "Test",
          preferred_public_key: "Tweewfweffefw"
        )
      end

      let(:credit_card) do
        CreditCard.create! do |cc|
          cc.encrypted_data = "weregergrewgregrewgregewrgewg"
        end
      end

      include_examples "creates profile on payment creation"
    end
  end
end
