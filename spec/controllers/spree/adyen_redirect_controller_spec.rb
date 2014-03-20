require 'spec_helper'

module Spree
  describe AdyenRedirectController do
    def params
      { "merchantReference"=>"R183301255",
        "skinCode"=>"Nonenone",
        "shopperLocale"=>"en_GB",
        "paymentMethod"=>"visa",
        "authResult"=>"AUTHORISED",
        "pspReference"=>"8813824003752247",
        "merchantSig"=>"erewrwerewrewrwer" }
    end

    let(:order) { create(:order_with_line_items, state: "payment") } 
    let(:payment_method) { Gateway::AdyenHPP.create(name: "Adyen") }
    
    before do
      controller.stub(current_order: order)
      controller.stub(:check_signature)
      controller.stub(payment_method: payment_method)
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
      expect(response).to redirect_to spree.order_path(order, :token => order.token)
    end

    pending "test check signature filter"
    pending "grab payment method by parameter (possibly merchantReturnData passed via session payment params)"
  end
end
