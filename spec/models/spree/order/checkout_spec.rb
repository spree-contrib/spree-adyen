require 'spec_helper'
require 'spree/testing_support/order_walkthrough'

module Spree
  describe Order do
    context 'with an associated user' do
      let(:order) { OrderWalkthrough.up_to(:delivery) }
      let(:credit_card) { create(:credit_card) }

      let(:gateway) { Gateway::AdyenPaymentEncrypted.create!(name: "Adyen") }

      let(:response) { double("Response", success?: true) }

      let(:details) do
        double("Details", details: [
          { card: { expiry_date: 1.year.from_now }, recurring_detail_reference: 123 }
        ])
      end

      before do
        Gateway::AdyenPaymentEncrypted.any_instance.stub_chain :provider, authorise_payment: response
        Gateway::AdyenPaymentEncrypted.any_instance.stub_chain :provider, list_recurring_details: details
      end

      it "transitions to complete just fine" do
        expect(order.state).to eq "payment"

        payment = order.payments.create! do |p|
          p.amount = 1
          p.source = credit_card
          p.payment_method = gateway
        end

        order.next!
        order.next!

        expect(order.state).to eq "complete"
      end
    end
  end
end
