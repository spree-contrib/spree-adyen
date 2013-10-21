require 'spec_helper'

describe AdyenNotification do
  let!(:payment) { create(:payment, response_code: params["pspReference"]) }

  def params
    { "pspReference" => "8513823667306210",
      "eventDate"=>"2013-10-21T14:45:45.93Z",
      "merchantAccountCode"=>"Test",
      "reason"=>"41061:1111:6/2016",
      "originalReference" => "",
      "value"=>"6999",
      "eventCode"=>"AUTHORISATION",
      "merchantReference"=>"R354361834-A3JC8TNJ",
      "operations"=>"CANCEL,CAPTURE,REFUND",
      "paymentMethod"=>"visa",
      "currency"=>"USD",
      "live"=>"false" }
  end

  context "receives notification of unsucessful payment auth" do
    let(:notification) { subject.class.log(params.merge("success"=>"false")) }

    it "invalidates payment" do
      expect(payment.reload).not_to be_invalid

      notification.handle!
      expect(payment.reload).to be_invalid
    end
  end

  context "receives notification of sucessful payment auth" do
    let(:notification) { subject.class.log(params.merge("success"=>"true")) }

    it "doesnt invalidate payment" do
      notification.handle!
      expect(payment.reload).not_to be_invalid
    end
  end
end
