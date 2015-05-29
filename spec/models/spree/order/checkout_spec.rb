require 'spec_helper'
require 'spree/testing_support/order_walkthrough'

module Spree
  describe Order do
    context 'with an associated user' do
      let(:order) { OrderWalkthrough.up_to(:payment) }
      let(:credit_card) { create(:credit_card) }

      let(:gateway) { Gateway::AdyenPaymentEncrypted.create!(name: "Adyen") }

      let(:response) { double("Response", success?: true) }

      let(:details) do
        double("Details", details: [
          { card: { number: "1111", expiry_date: 1.year.from_now }, recurring_detail_reference: 123 }
        ])
      end

      before do
        expect(gateway.provider).to receive(:authorise_payment).and_return(response)
        expect(gateway.provider).to receive(:list_recurring_details).and_return(details)
      end

      it "transitions to complete just fine" do
        expect(order.state).to eq "payment"

        payment = order.payments.create! do |p|
          p.amount = order.total
          p.source = credit_card
          p.payment_method = gateway
        end
        payment.complete
        order.payment_total = payment.amount


        order.next!
        expect(order.state).to eq "confirm"

        order.next!
        expect(order.state).to eq "complete"
      end
    end
  end
end
