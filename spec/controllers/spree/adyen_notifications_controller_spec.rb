require 'spec_helper'

module Spree
  describe AdyenNotificationsController do
    context "request authenticated" do
      before do
        ENV["ADYEN_NOTIFY_USER"] = "username"
        ENV["ADYEN_NOTIFY_PASSWD"] = "password"
        @request.env["HTTP_AUTHORIZATION"] = "Basic " + Base64::encode64("username:password")
      end

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
          "success"=>"true",
          "paymentMethod"=>"visa",
          "currency"=>"USD",
          "live"=>"false" }
      end

      it "logs notitification" do
        expect {
          spree_post :notify, params
        }.to change { AdyenNotification.count }.by(1)
      end
    end

    context "request not authenticated" do
      it "logs notitification" do
        spree_post :notify
        expect(response.status).to eq 401
      end
    end
  end
end
